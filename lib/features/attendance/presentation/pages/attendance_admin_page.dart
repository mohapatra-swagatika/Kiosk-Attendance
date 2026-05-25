import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/core/widgets/app_error_view.dart';
import 'package:attendance_kiosk_app/core/widgets/app_loading.dart';
import 'package:attendance_kiosk_app/core/widgets/dashboard/dashboard.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_filter_providers.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/widgets/attendance_log_detail_card.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/widgets/attendance_date_filter_bar.dart';

/// Admin attendance: all employees, filterable by date.
class AttendanceAdminPage extends ConsumerStatefulWidget {
  const AttendanceAdminPage({super.key});

  @override
  ConsumerState<AttendanceAdminPage> createState() =>
      _AttendanceAdminPageState();
}

class _AttendanceAdminPageState extends ConsumerState<AttendanceAdminPage> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(attendanceLogsForDateProvider(_selectedDay));
    final activeAsync = ref.watch(activeCheckInsTodayProvider);
    final timeFmt = DateFormat('h:mm a');
    final dateLabel = DateFormat.yMMMEd().format(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AttendanceDateFilterBar(
          title: AttendanceAdminStrings.title,
          subtitle: AttendanceAdminStrings.filterAllEmployees,
          selectedDay: _selectedDay,
          onDateChanged: (d) => setState(() => _selectedDay = d),
        ),
        Expanded(
          child: logsAsync.when(
            data: (logs) {
              final active = activeAsync.valueOrNull ?? [];
              final activeForDay = active
                  .where((l) => l.date == attendanceDateKey(_selectedDay))
                  .toList();

              return ResponsiveBuilder(
                builder: (context, bp, _) {
                  final pad = switch (bp) {
                    AppBreakpointSize.compact => 16.0,
                    AppBreakpointSize.medium => 24.0,
                    AppBreakpointSize.expanded => 28.0,
                  };
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // FilledButton.icon(
                        //   onPressed: () => context.push(RoutePaths.kiosk),
                        //   icon: const Icon(Icons.fullscreen),
                        //   label: const Text(AttendanceAdminStrings.startKiosk),
                        // ),
                        const SizedBox(height: 20),
                        DashboardMetricStrip(
                          metrics: [
                            DashboardMetric(
                              icon: Icons.list_alt,
                              label: AttendanceAdminStrings.metricDayLogs,
                              value: '${logs.length}',
                            ),
                            DashboardMetric(
                              icon: Icons.person_pin_circle,
                              label: AttendanceAdminStrings.metricActiveNow,
                              value: '${activeForDay.length}',
                            ),
                            DashboardMetric(
                              icon: Icons.calendar_today,
                              label: AttendanceAdminStrings.metricSelectedDay,
                              value: dateLabel,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        DashboardSectionHeader(
                          title: AttendanceAdminStrings.activeSectionTitle,
                          subtitle:
                              AttendanceAdminStrings.activeSectionSubtitle,
                        ),
                        const SizedBox(height: 12),
                        if (activeForDay.isEmpty)
                          const Text(AttendanceAdminStrings.activeEmpty)
                        else
                          ...activeForDay.map(
                            (l) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AttendanceLogDetailCard(
                                log: l,
                                showEmployee: true,
                                timeFormat: timeFmt,
                                filterDay: _selectedDay,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        DashboardSectionHeader(
                          title: AttendanceAdminStrings.historyTitle,
                          subtitle: AttendanceAdminStrings.historyForDate(
                            dateLabel,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (logs.isEmpty)
                          Text(
                            AttendanceAdminStrings.noRecordsForDate(dateLabel),
                          )
                        else
                          ...logs.map(
                            (l) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AttendanceLogDetailCard(
                                log: l,
                                showEmployee: true,
                                timeFormat: timeFmt,
                                filterDay: _selectedDay,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const AppLoading(),
            error: (e, _) => AppErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(attendanceLogsForDateProvider(_selectedDay)),
            ),
          ),
        ),
      ],
    );
  }
}
