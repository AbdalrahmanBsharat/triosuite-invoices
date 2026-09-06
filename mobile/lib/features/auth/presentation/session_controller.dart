import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/storage/secure_store.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// How far the app has got in deciding what to show first.
enum BootstrapPhase {
  /// Probing `/actuator/health`.
  connecting,

  /// The server did not answer. The user is offered a retry rather than an error.
  unreachable,

  /// Ready: [SessionController.user] says whether that means the list or the login screen.
  ready,
}

/// The signed-in session, and the decision about what the app opens on.
///
/// Kept permanently in memory because two things need to outlive every screen: the current account,
/// which drives what actions are offered, and the sign-out path the HTTP layer calls when a refresh
/// finally fails.
class SessionController extends GetxController {
  SessionController({
    required AuthRepository authRepository,
    required SecureStore secureStore,
    required ApiClient apiClient,
  })  : _auth = authRepository,
        _store = secureStore,
        _api = apiClient;

  final AuthRepository _auth;
  final SecureStore _store;
  final ApiClient _api;

  final Rx<BootstrapPhase> phase = BootstrapPhase.connecting.obs;
  final Rxn<AppUser> user = Rxn<AppUser>();
  final RxBool signingIn = false.obs;
  final RxnString signInError = RxnString();

  bool get isSignedIn => user.value != null;

  bool get isAdmin => user.value?.role.isAdmin ?? false;

  @override
  void onInit() {
    super.onInit();
    // The HTTP layer cannot construct this controller, so it is wired the other way round: once a
    // refresh has failed there is no session left to save, and every screen must return to login.
    _api.onSessionExpired = _endSessionLocally;
  }

  /// Decides the first screen.
  ///
  /// Waits on the health probe first, with a long timeout, because a free-tier backend sleeps after
  /// fifteen minutes idle and takes the better part of a minute to wake. Showing "cannot reach the
  /// server" to a reviewer whose backend is merely starting would be the worst possible first
  /// impression.
  Future<void> bootstrap() async {
    phase.value = BootstrapPhase.connecting;

    final reachable = await _api.checkHealth();
    if (!reachable) {
      phase.value = BootstrapPhase.unreachable;
      return;
    }

    // A stored access token may be expired; the interceptor will refresh it transparently. Only if
    // that also fails is the session genuinely over.
    final token = await _store.readAccessToken();
    if (token != null && token.isNotEmpty) {
      try {
        user.value = await _auth.me();
      } on ApiException {
        await _clearSession();
      }
    }

    phase.value = BootstrapPhase.ready;
  }

  /// Re-runs the health probe after the user taps Retry.
  Future<void> retryConnection() => bootstrap();

  /// Signs in and, on success, replaces the login screen with the invoice list.
  Future<void> signIn({required String username, required String password}) async {
    signingIn.value = true;
    signInError.value = null;
    try {
      final tokens = await _auth.login(username: username, password: password);
      await _store.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      user.value = tokens.user;
      await Get.offAllNamed<void>(AppRoutes.invoices);
    } on ApiException catch (error) {
      signInError.value = error.message;
    } finally {
      signingIn.value = false;
    }
  }

  /// Signs out, revoking the refresh token server-side first.
  ///
  /// The local session is cleared whatever the server says: a user who taps Sign out must end up
  /// signed out, even with no connectivity.
  Future<void> signOut() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _auth.logout(refreshToken);
      } on ApiException {
        // Already revoked, expired, or unreachable. Nothing here changes the outcome.
      }
    }
    await _clearSession();
    await Get.offAllNamed<void>(AppRoutes.login);
  }

  /// Called by the HTTP layer when a refresh fails. Drops the session and returns to login.
  Future<void> _endSessionLocally() async {
    if (!isSignedIn) {
      return;
    }
    await _clearSession();
    await Get.offAllNamed<void>(AppRoutes.login);
  }

  Future<void> _clearSession() async {
    await _store.clearTokens();
    user.value = null;
  }
}
