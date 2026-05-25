import 'package:equatable/equatable.dart';

import 'package:attendance_kiosk_app/core/auth/user_role.dart';

class AppSession extends Equatable {
  const AppSession({
    required this.displayName,
    required this.role,
    this.employeeId,
    this.loggedIn = true,
  });

  final String displayName;
  final UserRole role;
  final String? employeeId;
  final bool loggedIn;

  bool get isAdmin => role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;

  @override
  List<Object?> get props => [displayName, role, employeeId, loggedIn];
}
