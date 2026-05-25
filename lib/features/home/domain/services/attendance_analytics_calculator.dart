import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/home/domain/entities/dashboard_analytics.dart';

/// Computes dashboard KPIs from Hive attendance logs for a given day.
class AttendanceAnalyticsCalculator {
  AttendanceAnalyticsCalculator._();

  static const int shiftStartHour = 9;
  static const int shiftStartMinute = 0;

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  static DashboardAnalytics compute({
    required List<Employee> employees,
    required List<AttendanceLog> logs,
    DateTime? referenceDate,
  }) {
    final day = referenceDate ?? DateTime.now();
    final todayKey = _dateFmt.format(day);
    final todayLogs = logs.where((l) => l.date == todayKey).toList();

    final earliestCheckInByEmployee = <String, DateTime>{};
    for (final log in todayLogs) {
      final existing = earliestCheckInByEmployee[log.employeeId];
      if (existing == null || log.checkInTime.isBefore(existing)) {
        earliestCheckInByEmployee[log.employeeId] = log.checkInTime;
      }
    }

    final total = employees.length;
    final present = earliestCheckInByEmployee.length;
    final absent = total > present ? total - present : 0;

    var late = 0;
    for (final checkIn in earliestCheckInByEmployee.values) {
      if (_isLate(checkIn)) late++;
    }

    final attendancePct = total == 0 ? 0.0 : (present / total) * 100;
    final absentPct = total == 0 ? 0.0 : (absent / total) * 100;
    final latePct = present == 0 ? 0.0 : (late / present) * 100;

    // Punctuality reduces score when late rate is high; 100% when everyone on time.
    final punctualityFactor = 1 - (latePct / 100 * 0.35);
    final performance = (attendancePct * punctualityFactor).clamp(0.0, 100.0);

    return DashboardAnalytics(
      reportDate: day,
      totalEmployees: total,
      presentCount: present,
      absentCount: absent,
      lateCheckInCount: late,
      attendancePercentage: attendancePct,
      absentPercentage: absentPct,
      lateCheckInPercentage: latePct,
      performanceScore: performance,
    );
  }

  static bool _isLate(DateTime checkIn) {
    final threshold = DateTime(
      checkIn.year,
      checkIn.month,
      checkIn.day,
      shiftStartHour,
      shiftStartMinute,
    );
    return checkIn.isAfter(threshold);
  }
}
