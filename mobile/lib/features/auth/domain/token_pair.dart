import 'package:freezed_annotation/freezed_annotation.dart';

import 'app_user.dart';

part 'token_pair.freezed.dart';
part 'token_pair.g.dart';

/// A freshly issued pair of tokens plus the account they belong to.
///
/// The refresh token is single-use: presenting it returns a new pair and revokes the one presented,
/// so whatever is stored on the device is replaced on every refresh.
@freezed
abstract class TokenPair with _$TokenPair {
  const factory TokenPair({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
    required AppUser user,
  }) = _TokenPair;

  factory TokenPair.fromJson(Map<String, dynamic> json) => _$TokenPairFromJson(json);
}
