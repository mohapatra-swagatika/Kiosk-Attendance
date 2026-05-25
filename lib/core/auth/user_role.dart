/// Local session role for role-based navigation.
enum UserRole {
  admin('admin'),
  employee('employee');

  const UserRole(this.value);
  final String value;

  static UserRole fromValue(String? v) {
    return UserRole.values.firstWhere(
      (e) => e.value == v,
      orElse: () => UserRole.employee,
    );
  }
}
