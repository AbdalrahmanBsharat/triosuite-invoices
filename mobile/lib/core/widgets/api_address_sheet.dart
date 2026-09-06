import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../storage/secure_store.dart';
import 'app_snackbar.dart';

/// Lets the user point the app at a different backend.
///
/// This is the reviewer's escape hatch. If the hosted API is asleep, has been taken down, or was
/// never reachable from their network, they can type their own address here instead of needing the
/// APK rebuilt. It is reachable from two places for that reason: the Settings screen, and the
/// "cannot reach the server" state on start-up, which is exactly when it is needed.
///
/// The value is stored on the device and wins over whatever was compiled in with
/// `--dart-define=API_BASE_URL`.
class ApiAddressSheet extends StatefulWidget {
  const ApiAddressSheet({super.key, required this.onChanged});

  /// Called after a new address has been saved, so the caller can retry whatever failed.
  final Future<void> Function() onChanged;

  /// Opens the sheet.
  static Future<void> show({required Future<void> Function() onChanged}) {
    final context = Get.context;
    if (context == null) {
      return Future<void>.value();
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ApiAddressSheet(onChanged: onChanged),
    );
  }

  @override
  State<ApiAddressSheet> createState() => _ApiAddressSheetState();
}

class _ApiAddressSheetState extends State<ApiAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _store = Get.find<SecureStore>();
  final _api = Get.find<ApiClient>();

  bool _testing = false;
  bool _saving = false;
  String? _testResult;
  bool _testPassed = false;

  @override
  void initState() {
    super.initState();
    _controller.text = _api.baseUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter the API address, or reset to the built-in default';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Must be a full address starting with http:// or https://';
    }
    if (uri.host.isEmpty) {
      return 'That address has no host';
    }
    return null;
  }

  /// Probes the typed address before committing to it, so a typo is caught here rather than as a
  /// stream of failures on every later screen.
  Future<void> _test() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final reachable = await _api.checkHealth(baseUrlOverride: _controller.text.trim());

    if (!mounted) {
      return;
    }
    setState(() {
      _testing = false;
      _testPassed = reachable;
      _testResult = reachable
          ? 'Connected. The API answered and reports it is healthy.'
          : 'No answer. Check the address, and that the backend is running.';
    });
  }

  Future<void> _save({required bool useDefault}) async {
    if (!useDefault && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);

    final baseUrl = useDefault ? AppConfig.buildTimeBaseUrl : _controller.text.trim();
    await _store.saveBaseUrlOverride(useDefault ? null : baseUrl);
    _api.setBaseUrl(baseUrl);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    AppSnackbar.success('API address set to $baseUrl');
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _testing || _saving;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('API address', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Where this app looks for the backend. Stored on this device only.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              validator: _validate,
              onChanged: (_) => setState(() => _testResult = null),
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://triosuite-invoices.onrender.com',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Built-in default: ${AppConfig.buildTimeBaseUrl}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _testPassed ? Icons.check_circle_outline : Icons.error_outline,
                    size: 18,
                    color: _testPassed ? theme.colorScheme.primary : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            _testPassed ? theme.colorScheme.primary : theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: busy ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_testing ? 'Testing…' : 'Test connection'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: busy ? null : () => _save(useDefault: false),
              child: const Text('Save'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: busy ? null : () => _save(useDefault: true),
              child: const Text('Reset to the built-in default'),
            ),
          ],
        ),
      ),
    );
  }
}
