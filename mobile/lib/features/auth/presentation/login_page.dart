import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/api_address_sheet.dart';
import 'session_controller.dart';

/// Sign-in, and the app's first screen.
///
/// It doubles as the start-up gate. While the health probe runs it shows "Connecting…", and if the
/// server does not answer it offers a retry and a way to correct the API address rather than an
/// error the user can do nothing about. Only once the server has answered does the form appear —
/// or, if a stored session is still valid, the session controller has already replaced this screen
/// with the invoice list.
///
/// There is no "create account" affordance anywhere: the API has no registration endpoint, and
/// offering one would be a lie.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _session = Get.find<SessionController>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _session.signIn(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Obx(() => switch (_session.phase.value) {
              BootstrapPhase.connecting => const _ConnectingView(),
              BootstrapPhase.unreachable => _UnreachableView(session: _session),
              BootstrapPhase.ready => _buildForm(context),
            }),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Triosuite Invoices',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to create and manage sales invoices.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      key: const Key('login_username'),
                      controller: _usernameController,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Enter your username'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('login_password'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          key: const Key('login_toggle_password'),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        ),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Enter your password' : null,
                    ),
                    const SizedBox(height: 12),
                    Obx(() {
                      final error = _session.signInError.value;
                      if (error == null) {
                        return const SizedBox(height: 8);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline,
                                size: 18, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error,
                                key: const Key('login_error'),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Obx(() {
                      final busy = _session.signingIn.value;
                      return FilledButton(
                        key: const Key('login_submit'),
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Sign in'),
                      );
                    }),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: () => ApiAddressSheet.show(
                        onChanged: _session.retryConnection,
                      ),
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: const Text('Change API address'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while the health probe is in flight.
class _ConnectingView extends StatelessWidget {
  const _ConnectingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 28),
            Text('Connecting to server…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'The backend runs on a free tier that sleeps when idle, so the first request of '
              'the day can take up to a minute to wake it.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the health probe came back empty-handed.
class _UnreachableView extends StatelessWidget {
  const _UnreachableView({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 20),
            Text("Can't reach the server", style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Check your connection, then try again. If you are running the backend yourself, '
              'set the API address to point at it.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: session.retryConnection,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ApiAddressSheet.show(onChanged: session.retryConnection),
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: const Text('Change API address'),
            ),
          ],
        ),
      ),
    );
  }
}
