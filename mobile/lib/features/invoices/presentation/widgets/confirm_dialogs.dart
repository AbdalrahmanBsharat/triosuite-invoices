import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The confirmations that guard the two irreversible actions.
///
/// Approving locks an invoice for good and cancelling cannot be undone, so neither happens on a
/// single tap. Both dialogs say what will actually change rather than asking "are you sure?".
abstract final class ConfirmDialogs {
  const ConfirmDialogs._();

  /// Asks before approving. Returns true when the user confirmed.
  static Future<bool> approve({required String invoiceNumber}) async {
    final context = Get.context;
    if (context == null) {
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.lock_outline),
        title: const Text('Approve this invoice?'),
        content: Text(
          '$invoiceNumber will be locked. Its lines, totals and customer can no longer be '
          'changed — the only action left will be to cancel it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Asks before cancelling, collecting an optional reason.
  ///
  /// Returns the reason — possibly an empty string — when the user confirmed, or null when they
  /// backed out. An empty string and null therefore mean different things, which is why this does
  /// not simply return a nullable reason.
  static Future<String?> cancel({required String invoiceNumber}) async {
    final context = Get.context;
    if (context == null) {
      return null;
    }

    final reasonController = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.block),
          title: const Text('Cancel this invoice?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$invoiceNumber will be marked cancelled. Nothing is deleted — it stays in the '
                'list under the Cancelled filter, with its lines and totals intact.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLength: 500,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Why is this invoice being withdrawn?',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep it'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(reasonController.text.trim()),
              child: const Text('Cancel invoice'),
            ),
          ],
        ),
      );
    } finally {
      reasonController.dispose();
    }
  }

  /// Asks before discarding unsaved edits to a draft.
  static Future<bool> discardChanges() async {
    final context = Get.context;
    if (context == null) {
      return true;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('This invoice has not been saved. Leaving now loses your edits.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
