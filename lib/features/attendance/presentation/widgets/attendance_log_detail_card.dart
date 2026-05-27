import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/widgets/attendance_record_photo_thumb.dart';

/// Human-readable labels for attendance status (never raw enum values).
String attendanceStatusLabel(AttendanceLog log) {
  if (log.isActiveCheckIn) {
    return AttendanceDetailStrings.statusCheckedIn;
  }
  if (log.checkOutTime != null) {
    return AttendanceDetailStrings.statusCheckedOut;
  }
  return AttendanceDetailStrings.statusCheckedIn;
}

Color attendanceStatusColor(AttendanceLog log, ColorScheme scheme) {
  if (log.isActiveCheckIn) return scheme.primary;
  if (log.checkOutTime != null) return Colors.green.shade700;
  return scheme.outline;
}

/// Primary line for a session (time range or check-in only).
String attendanceSessionTitle(AttendanceLog log, DateFormat timeFmt) {
  final inTime = timeFmt.format(log.checkInTime);
  if (log.checkOutTime == null) {
    return AttendanceDetailStrings.checkInAt(inTime);
  }
  final outTime = timeFmt.format(log.checkOutTime!);
  return AttendanceDetailStrings.sessionTimeRange(inTime, outTime);
}

String? attendanceDurationLabel(AttendanceLog log) {
  final out = log.checkOutTime;
  if (out == null) return null;
  final duration = out.difference(log.checkInTime);
  if (duration.isNegative) return null;
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return AttendanceDetailStrings.durationHoursMinutes(hours, minutes);
  }
  return AttendanceDetailStrings.durationMinutes(minutes);
}

/// Date heading for grouping (full calendar date).
String attendanceDateHeading(AttendanceLog log) {
  return DateFormat.yMMMEd().format(log.checkInTime);
}

/// Card showing formatted attendance session details.
class AttendanceLogDetailCard extends StatelessWidget {
  const AttendanceLogDetailCard({
    super.key,
    required this.log,
    this.showEmployee = false,
    this.employeeCodeForDisplay,
    this.timeFormat,
    this.filterDay,
    this.useDateAsTitle = false,
  });

  final AttendanceLog log;
  final bool showEmployee;
  /// When [showEmployee] is true, shows this code instead of [log.employeeId].
  /// Falls back to [log.employeeId] if null/empty.
  final String? employeeCodeForDisplay;
  final DateFormat? timeFormat;

  /// When set, hides the date line if the log falls on this day (admin date filter).
  final DateTime? filterDay;

  /// Employee list: show calendar date as the main title on every record.
  final bool useDateAsTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeFmt = timeFormat ?? DateFormat.jm();
    final status = attendanceStatusLabel(log);
    final statusColor = attendanceStatusColor(log, scheme);
    final duration = attendanceDurationLabel(log);
    final showDateLine =
        useDateAsTitle || filterDay == null || !_isSameDay(log.checkInTime, filterDay!);
    final displayEmployeeId =
        (employeeCodeForDisplay != null && employeeCodeForDisplay!.isNotEmpty)
            ? employeeCodeForDisplay!
            : log.employeeId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AttendanceRecordPhotoThumb(log: log),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showEmployee) ...[
                    Text(
                      log.employeeName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayEmployeeId,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (showDateLine) ...[
                    Text(
                      attendanceDateHeading(log),
                      style: useDateAsTitle
                          ? Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              )
                          : Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    attendanceSessionTitle(log, timeFmt),
                    style: useDateAsTitle
                        ? Theme.of(context).textTheme.bodyLarge
                        : Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                  if (duration != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      duration,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            Chip(
              label: Text(status),
              visualDensity: VisualDensity.compact,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide.none,
            ),
          ],
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
