import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The app's transient messages.
///
/// One helper rather than `Get.snackbar` calls scattered through the screens, so success and
/// failure always look different from each other and always look the same as themselves.
abstract final class AppSnackbar {
  const AppSnackbar._();

  static void success(String message) => _show(message, isError: false);

  static void failure(String message) => _show(message, isError: true);

  static void _show(String message, {required bool isError}) {
    final context = Get.context;
    if (context == null) {
      return;
    }
    final colors = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? colors.onErrorContainer : colors.onInverseSurface,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: isError ? colors.onErrorContainer : colors.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? colors.errorContainer : colors.inverseSurface,
          duration: Duration(seconds: isError ? 5 : 3),
        ),
      );
  }
}
