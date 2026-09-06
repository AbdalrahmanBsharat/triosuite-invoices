import 'package:flutter/material.dart';

/// The three states any list or detail screen can be in, in one place.
///
/// Every screen in the app routes through this rather than inventing its own spinner and its own
/// error text, so "loading", "nothing here" and "that failed, try again" look and behave the same
/// everywhere — and no screen can quietly forget one of the three.
class AsyncStateView extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.error,
    required this.onRetry,
    required this.child,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyAction,
  });

  /// True only for the *first* load. A refresh keeps the existing content on screen.
  final bool isLoading;

  final bool isEmpty;

  /// A message safe to show the user, or null when the last attempt succeeded.
  final String? error;

  final Future<void> Function() onRetry;

  /// What to show once there is something to show.
  final Widget child;

  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: error!,
        action: FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    if (isEmpty) {
      return _MessageState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
        action: emptyAction,
      );
    }

    return child;
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
