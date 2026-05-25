import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/widgets/attendance_date_filter_bar.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/widgets/attendance_log_detail_card.dart';
import 'package:attendance_kiosk_app/features/auth/login/presentation/providers/login_providers.dart';
import 'package:attendance_kiosk_app/features/employee_portal/presentation/providers/employee_portal_providers.dart';

/// Logged-in employee attendance history with date filter.
class EmployeeAttendanceRecordsPage extends ConsumerStatefulWidget {
  const EmployeeAttendanceRecordsPage({super.key});

  @override
  ConsumerState<EmployeeAttendanceRecordsPage> createState() =>
      _EmployeeAttendanceRecordsPageState();
}

class _EmployeeAttendanceRecordsPageState
    extends ConsumerState<EmployeeAttendanceRecordsPage> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);
    final dateLabel = DateFormat.yMMMEd().format(_selectedDay);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (session) {
        if (session == null || !session.loggedIn || session.employeeId == null) {
          return const Center(child: Text(EmployeePortalStrings.sessionMissing));
        }

        final logsAsync = ref.watch(employeeAttendanceLogsProvider(_selectedDay));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AttendanceDateFilterBar(
              title: EmployeePortalStrings.attendanceTab,
              subtitle: EmployeePortalStrings.filterByDate,
              selectedDay: _selectedDay,
              onDateChanged: (d) => setState(() => _selectedDay = d),
            ),
            Expanded(
              child: logsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (logs) {
                  if (logs.isEmpty) {
                    return Center(
                      child: Text(
                        EmployeePortalStrings.noRecordsForDate(dateLabel),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => AttendanceLogDetailCard(
                      log: logs[i],
                      showEmployee: false,
                      useDateAsTitle: true,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
