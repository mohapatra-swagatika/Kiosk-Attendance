import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_filter_providers.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/auth/login/presentation/providers/login_providers.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';

/// Logged-in employee from local session + employee roster.
final sessionEmployeeProvider = FutureProvider<Employee?>((ref) async {
  final session = await ref.watch(appSessionProvider.future);
  if (session == null || !session.loggedIn) return null;

  final employeeId = session.employeeId;
  if (employeeId == null) return null;

  final list = await ref.watch(employeesListProvider.future);
  for (final e in list) {
    if (e.id == employeeId) return e;
  }
  return null;
});

final employeeActiveCheckInProvider = FutureProvider<AttendanceLog?>((ref) async {
  final session = await ref.watch(appSessionProvider.future);
  final employeeId = session?.employeeId;
  if (employeeId == null || session?.loggedIn != true) return null;

  final result =
      await ref.read(attendanceRepositoryProvider).getActiveCheckIn(employeeId);
  return result.fold((_) => null, (log) => log);
});

final employeeAttendanceLogsProvider =
    FutureProvider.family<List<AttendanceLog>, DateTime>((ref, day) async {
  final session = await ref.watch(appSessionProvider.future);
  final employeeId = session?.employeeId;
  if (employeeId == null || session?.loggedIn != true) return [];

  final logs = await ref.watch(attendanceLogsForDateProvider(day).future);
  return logs.where((l) => l.employeeId == employeeId).toList();
});
