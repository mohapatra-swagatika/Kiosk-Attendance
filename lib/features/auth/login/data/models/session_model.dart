import 'package:attendance_kiosk_app/core/auth/user_role.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/entities/app_session.dart';

/// Local session payload stored in Hive (offline-first; APIs plug in later).
class SessionModel {
  const SessionModel({
    required this.displayName,
    required this.role,
    required this.loggedIn,
    this.employeeId,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      displayName: json['displayName'] as String? ??
          json['username'] as String? ??
          '',
      role: UserRole.fromValue(json['role'] as String?),
      employeeId: json['employeeId'] as String?,
      loggedIn: json['loggedIn'] as bool? ?? false,
    );
  }

  factory SessionModel.fromSession(AppSession session) => SessionModel(
        displayName: session.displayName,
        role: session.role,
        employeeId: session.employeeId,
        loggedIn: session.loggedIn,
      );

  final String displayName;
  final UserRole role;
  final String? employeeId;
  final bool loggedIn;

  AppSession toEntity() => AppSession(
        displayName: displayName,
        role: role,
        employeeId: employeeId,
        loggedIn: loggedIn,
      );

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'role': role.value,
        if (employeeId != null) 'employeeId': employeeId,
        'loggedIn': loggedIn,
      };
}
