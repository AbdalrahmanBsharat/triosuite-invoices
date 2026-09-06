import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Everything the app persists between launches.
///
/// Tokens go through `flutter_secure_storage`, which on Android is backed by the Keystore, so a
/// bearer credential is never sitting in plain shared preferences where any backup or rooted
/// device could read it. The two non-secret preferences — the API base URL override and the theme
/// choice — live in the same store simply because there is no reason to add a second dependency
/// for two strings.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // The v11 defaults already wrap an AES-GCM data key with an RSA key held in the
              // Android Keystore. The namespace keeps these entries distinct from anything else
              // the package may store for another library in the same app.
              aOptions: AndroidOptions(storageNamespace: 'triosuite_invoices'),
            );

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _baseUrlOverrideKey = 'api_base_url_override';
  static const String _themeModeKey = 'theme_mode';

  final FlutterSecureStorage _storage;

  // -------------------------------------------------------------------------------------
  // Tokens
  // -------------------------------------------------------------------------------------

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Clears the session without touching the device preferences.
  ///
  /// Signing out must not discard the API base URL the reviewer typed in, or they would have to
  /// enter it again on every login.
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  // -------------------------------------------------------------------------------------
  // Preferences
  // -------------------------------------------------------------------------------------

  /// The API base URL typed on the Settings screen, or null when the compiled default applies.
  Future<String?> readBaseUrlOverride() async {
    final value = await _storage.read(key: _baseUrlOverrideKey);
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> saveBaseUrlOverride(String? baseUrl) async {
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      await _storage.delete(key: _baseUrlOverrideKey);
    } else {
      await _storage.write(key: _baseUrlOverrideKey, value: baseUrl.trim());
    }
  }

  Future<ThemeMode> readThemeMode() async {
    final value = await _storage.read(key: _themeModeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) =>
      _storage.write(key: _themeModeKey, value: mode.name);
}
