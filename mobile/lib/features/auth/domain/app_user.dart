/// What the caller is allowed to do.
///
/// The app hides actions a role cannot perform, but that is convenience only — every rule is
/// enforced again on the server, on data it loaded itself.
enum UserRole {
  /// Everything, including cancelling invoices and maintaining settings and exchange rates.
  admin('ADMIN', 'Administrator'),

  /// Reads everything; creates and edits drafts; approves.
  sales('SALES', 'Sales');

  const UserRole(this.wireName, this.label);

  /// The value the API uses for this role.
  final String wireName;

  /// The name shown in the UI.
  final String label;

  bool get isAdmin => this == UserRole.admin;

  /// Anything unrecognised becomes [sales], the less privileged of the two — so a role added to
  /// the server later cannot accidentally unlock admin-only buttons in an older build.
  static UserRole fromWire(String? wireName) => UserRole.values.firstWhere(
        (role) => role.wireName == wireName,
        orElse: () => UserRole.sales,
      );
}

/// The signed-in account, as returned by login, refresh and `GET /api/auth/me`.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String username;
  final String fullName;
  final UserRole role;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: json['fullName'] as String,
      role: UserRole.fromWire(json['role'] as String?),
    );
  }
}
