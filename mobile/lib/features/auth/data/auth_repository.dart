import '../../../core/network/api_client.dart';
import '../domain/app_user.dart';
import '../domain/token_pair.dart';

/// Sign-in, sign-out and "who am I".
///
/// Token *refresh* is deliberately absent: it happens inside the Dio interceptor, transparently,
/// so no screen ever has to think about an expiring access token.
class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  Future<TokenPair> login({
    required String username,
    required String password,
  }) async {
    final json = await _api.post('/api/auth/login', body: {
      'username': username,
      'password': password,
    });
    return TokenPair.fromJson(json as Map<String, dynamic>);
  }

  /// Revokes a refresh token server-side.
  ///
  /// Idempotent by design: an unknown or already revoked token still returns 204, so a sign-out
  /// never fails in a way the user has to care about.
  Future<void> logout(String refreshToken) =>
      _api.post('/api/auth/logout', body: {'refreshToken': refreshToken});

  /// Resolves the stored access token to an account, refreshing it first if it has expired.
  Future<AppUser> me() async {
    final json = await _api.get('/api/auth/me');
    return AppUser.fromJson(json as Map<String, dynamic>);
  }
}
