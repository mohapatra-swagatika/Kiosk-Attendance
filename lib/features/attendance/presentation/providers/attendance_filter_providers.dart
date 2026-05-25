import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';

String attendanceDateKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

final attendanceLogsForDateProvider =
    FutureProvider.family<List<AttendanceLog>, DateTime>((ref, day) async {
  final logs = await ref.watch(attendanceLogsProvider.future);
  final key = attendanceDateKey(day);
  return logs.where((l) => l.date == key).toList()
    ..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
});
