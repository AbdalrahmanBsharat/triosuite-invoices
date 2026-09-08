import 'app_user.dart';

/// A freshly issued pair of tokens plus the account they belong to.
///
/// The refresh token is single-use: presenting it returns a new pair and revokes the one presented,
/// so whatever is stored on the device is replaced on every refresh.
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresInSeconds;
  final AppUser user;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresInSeconds: json['expiresInSeconds'] as int,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
