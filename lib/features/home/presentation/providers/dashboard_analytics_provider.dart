import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/home/domain/entities/dashboard_analytics.dart';
import 'package:attendance_kiosk_app/features/home/domain/services/attendance_analytics_calculator.dart';

final dashboardAnalyticsProvider = FutureProvider<DashboardAnalytics>((ref) async {
  final employees = await ref.watch(employeesListProvider.future);
  final logs = await ref.watch(attendanceLogsProvider.future);
  return AttendanceAnalyticsCalculator.compute(
    employees: employees,
    logs: logs,
  );
});
