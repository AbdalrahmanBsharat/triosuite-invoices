import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

/// What the caller is allowed to do.
///
/// The app hides actions a role cannot perform, but that is convenience only — every rule is
/// enforced again on the server, on data it loaded itself.
enum UserRole {
  /// Everything, including cancelling invoices and maintaining settings and exchange rates.
  @JsonValue('ADMIN')
  admin,

  /// Reads everything; creates and edits drafts; approves.
  @JsonValue('SALES')
  sales;

  bool get isAdmin => this == UserRole.admin;

  String get label => switch (this) {
        UserRole.admin => 'Administrator',
        UserRole.sales => 'Sales',
      };
}

/// The signed-in account, as returned by login, refresh and `GET /api/auth/me`.
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required int id,
    required String username,
    required String fullName,
    required UserRole role,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
}
