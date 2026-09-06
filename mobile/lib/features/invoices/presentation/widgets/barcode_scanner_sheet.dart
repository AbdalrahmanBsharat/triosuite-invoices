import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// What happened to a scanned code, so the sheet can report it without knowing anything about
/// invoices.
class ScanOutcome {
  const ScanOutcome({required this.message, required this.success});

  /// A line was added, or an existing one had its quantity bumped.
  const ScanOutcome.added(this.message) : success = true;

  /// Nothing in the catalogue carries that code, or the lookup failed.
  const ScanOutcome.rejected(this.message) : success = false;

  final String message;
  final bool success;
}

/// The camera sheet that turns a barcode into an invoice line.
///
/// It deliberately stays open after each scan. Adding six items means scanning six labels, and
/// closing the camera between each one would make that far slower than typing. Each result appears
/// in a running list at the bottom, so the user can see what has gone on without leaving.
///
/// Duplicate suppression happens in two places: `DetectionSpeed.noDuplicates` stops the same code
/// firing repeatedly while it sits in frame, and [_inFlight] stops a second lookup starting before
/// the first has answered.
class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key, required this.onBarcode});

  /// Looks the code up and applies it to the invoice, returning what to tell the user.
  final Future<ScanOutcome> Function(String barcode) onBarcode;

  /// Opens the scanner.
  static Future<void> show({
    required Future<ScanOutcome> Function(String barcode) onBarcode,
  }) {
    final context = Get.context;
    if (context == null) {
      return Future<void>.value();
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BarcodeScannerSheet(onBarcode: onBarcode),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  /// The retail symbologies the seeded catalogue uses, plus the two Code formats a warehouse label
  /// is likely to carry. Narrowing the list makes detection noticeably faster and stops the scanner
  /// locking onto a QR code stuck to the same box.
  static const List<BarcodeFormat> _formats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
  ];

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: _formats,
  );

  final List<ScanOutcome> _history = [];
  bool _inFlight = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_inFlight) {
      return;
    }
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .firstWhere((value) => value != null && value.isNotEmpty, orElse: () => null);
    if (code == null) {
      return;
    }

    setState(() => _inFlight = true);
    final outcome = await widget.onBarcode(code);

    if (!mounted) {
      return;
    }
    setState(() {
      _inFlight = false;
      _history.insert(0, outcome);
    });

    // A short buzz for a hit and a sharper one for a miss: with the phone held up to a shelf, the
    // screen is often not where the user is looking.
    unawaited(outcome.success ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Scan a barcode', style: theme.textTheme.titleLarge),
              ),
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (context, state, _) {
                  if (state.torchState == TorchState.unavailable) {
                    return const SizedBox.shrink();
                  }
                  final isOn = state.torchState == TorchState.on;
                  return IconButton(
                    onPressed: () => unawaited(_controller.toggleTorch()),
                    icon: Icon(isOn ? Icons.flashlight_on : Icons.flashlight_off),
                    tooltip: isOn ? 'Turn the torch off' : 'Turn the torch on',
                    color: isOn ? theme.colorScheme.primary : null,
                  );
                },
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Done',
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) => unawaited(_onDetect(capture)),
                    errorBuilder: (context, error) => _ScannerError(error: error),
                    placeholderBuilder: (context) =>
                        const ColoredBox(color: Colors.black12),
                  ),
                  const _ReticleOverlay(),
                  if (_inFlight)
                    const ColoredBox(
                      color: Colors.black38,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Point the camera at a barcode. The sheet stays open so you can scan several in a row.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 132),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final outcome = _history[index];
                  final color =
                      outcome.success ? theme.colorScheme.primary : theme.colorScheme.error;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          outcome.success ? Icons.check_circle_outline : Icons.error_outline,
                          size: 17,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            outcome.message,
                            style: theme.textTheme.bodySmall?.copyWith(color: color),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The corner brackets that tell the user where to aim.
class _ReticleOverlay extends StatelessWidget {
  const _ReticleOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.78,
          heightFactor: 0.42,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the preview when the camera cannot be used.
///
/// A denied permission is by far the most common case and the only one the user can fix, so it gets
/// its own message and a button into the system settings rather than a generic failure.
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;

    final (String title, String message) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
          'Camera access is off',
          'Allow camera access for Triosuite Invoices, then reopen the scanner. You can still add '
              'items with the picker.',
        ),
      MobileScannerErrorCode.unsupported => (
          'No usable camera',
          'This device has no camera the scanner can use. Add items with the picker instead.',
        ),
      _ => (
          'The camera could not start',
          'Close this sheet and try again. You can add items with the picker in the meantime.',
        ),
    };

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied
                    ? Icons.no_photography_outlined
                    : unsupported
                        ? Icons.videocam_off_outlined
                        : Icons.error_outline,
                size: 44,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
