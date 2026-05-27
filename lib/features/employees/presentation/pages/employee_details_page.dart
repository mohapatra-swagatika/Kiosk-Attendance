import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/core/widgets/app_loading.dart';
import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/widgets/attendance_date_filter_bar.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/widgets/attendance_log_detail_card.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/widgets/employee_avatar.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/widgets/employee_config_action_button.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/widgets/employee_face_config_sheet.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/widgets/employee_pin_sheet.dart';

/// Admin view: profile, config actions (sheets), date-filtered attendance at bottom.
class EmployeeDetailsPage extends ConsumerStatefulWidget {
  const EmployeeDetailsPage({
    super.key,
    required this.employeeId,
    this.initialEmployee,
  });

  final String employeeId;

  /// Snapshot / roster row passed from navigation for immediate bind.
  final Employee? initialEmployee;

  @override
  ConsumerState<EmployeeDetailsPage> createState() => _EmployeeDetailsPageState();
}

class _EmployeeDetailsPageState extends ConsumerState<EmployeeDetailsPage> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final employeeAsync = ref.watch(employeeByIdProvider(widget.employeeId));

    if (employeeAsync.isLoading && widget.initialEmployee != null) {
      return _buildBody(context, widget.initialEmployee!);
    }

    return employeeAsync.when(
      loading: () =>
          widget.initialEmployee != null ? _buildBody(context, widget.initialEmployee!) : const AppLoading(),
      error: (e, _) {
        if (widget.initialEmployee != null) {
          return _buildBody(context, widget.initialEmployee!);
        }
        return Center(child: Text(e.toString()));
      },
      data: (employee) {
        final resolved = employee ?? widget.initialEmployee;
        if (resolved == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(EmployeeDetailsStrings.notFound),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text(AppStrings.dismiss),
                ),
              ],
            ),
          );
        }

        return _buildBody(context, resolved);
      },
    );
  }

  Widget _buildBody(BuildContext context, Employee employee) {
    final logsAsync = ref.watch(
      employeeAttendanceLogsForDateProvider(
        (employeeId: employee.id, day: _selectedDay),
      ),
    );
    final dateLabel = DateFormat.yMMMEd().format(_selectedDay);
    final timeFmt = DateFormat('h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailsHeader(
          onBack: () => context.pop(),
          employeeName: employee.name,
        ),
        Expanded(
          child: ResponsiveBuilder(
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
                    Center(
                      child: EmployeeAvatar(
                        employee: employee,
                        size: 140,
                        borderRadius: 24,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _EmployeeInfo(employee: employee),
                    const SizedBox(height: 20),
                    _ConfigActions(employee: employee),
                    const SizedBox(height: 28),
                    _AttendanceSection(
                      selectedDay: _selectedDay,
                      onDateChanged: (d) => setState(() => _selectedDay = d),
                      logsAsync: logsAsync,
                      dateLabel: dateLabel,
                      timeFmt: timeFmt,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({
    required this.onBack,
    required this.employeeName,
  });

  final VoidCallback onBack;
  final String employeeName;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: AppStrings.back,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    EmployeeDetailsStrings.title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    employeeName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeInfo extends ConsumerWidget {
  const _EmployeeInfo({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasFaceAsync = ref.watch(employeeHasFaceEmbeddingProvider(employee.id));

    final faceLabel = hasFaceAsync.when(
      data: (has) => has
          ? EmployeeCardStrings.faceRegistered
          : EmployeeCardStrings.faceNotConfigured,
      loading: () => employee.faceRegistered
          ? EmployeeCardStrings.faceRegistered
          : EmployeeCardStrings.faceNotConfigured,
      error: (_, __) => EmployeeCardStrings.faceNotConfigured,
    );
    final faceRegistered = hasFaceAsync.valueOrNull ?? employee.faceRegistered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          employee.name,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        if (employee.designation != null && employee.designation!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            employee.designation!,
            style: textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  EmployeeDetailsStrings.profileSectionTitle,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (employee.employeeCode != null && employee.employeeCode!.isNotEmpty)
                  _DetailRow(
                    label: EmployeeDetailsStrings.labelEmployeeCode,
                    value: employee.employeeCode!,
                  ),
                if (employee.workStatus != null && employee.workStatus!.isNotEmpty)
                  _DetailRow(
                    label: EmployeeDetailsStrings.labelStatus,
                    value: employee.workStatus!,
                  ),
                if (employee.department.isNotEmpty)
                  _DetailRow(
                    label: EmployeeDetailsStrings.labelDepartment,
                    value: employee.department,
                  ),
                if (employee.location != null && employee.location!.isNotEmpty)
                  _DetailRow(
                    label: EmployeeDetailsStrings.labelLocation,
                    value: employee.location!,
                  ),
                if (employee.reportingManager != null &&
                    employee.reportingManager!.isNotEmpty)
                  _DetailRow(
                    label: EmployeeDetailsStrings.labelReportingManager,
                    value: employee.reportingManager!,
                  ),
                if (employee.todayShift != null)
                  _DetailRow(
                    label: EmployeeDetailsStrings.labelTodayShift,
                    value: EmployeeDetailsStrings.todayShiftValue(
                      employee.todayShift!.shiftName,
                      employee.todayShift!.shiftCode,
                    ),
                  ),
                if (employee.email != null && employee.email!.isNotEmpty)
                  _DetailRow(
                    label: EmployeeDetailsStrings.labelEmail,
                    value: employee.email!,
                  ),
                if (employee.phone != null && employee.phone!.isNotEmpty)
                  _DetailRow(
                    label: EmployeeDetailsStrings.labelPhone,
                    value: employee.phone!,
                  ),
                _DetailRow(
                  label: EmployeeDetailsStrings.labelPin,
                  value: employee.pin,
                ),
                _DetailRow(
                  label: EmployeeDetailsStrings.labelFace,
                  value: faceLabel,
                  trailing: Icon(
                    faceRegistered ? Icons.verified_user : Icons.face_retouching_natural,
                    size: 20,
                    color: faceRegistered ? scheme.primary : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ConfigActions extends ConsumerWidget {
  const _ConfigActions({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: EmployeeConfigActionButton(
            icon: Icons.face_retouching_natural_outlined,
            label: EmployeeDetailsStrings.faceConfigButton,
            onPressed: () => showEmployeeFaceConfigSheet(
              context: context,
              ref: ref,
              employee: employee,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: EmployeeConfigActionButton(
            icon: Icons.pin_outlined,
            label: EmployeeDetailsStrings.pinConfigButton,
            onPressed: () => showEmployeePinSheet(
              context: context,
              employee: employee,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({
    required this.selectedDay,
    required this.onDateChanged,
    required this.logsAsync,
    required this.dateLabel,
    required this.timeFmt,
  });

  final DateTime selectedDay;
  final ValueChanged<DateTime> onDateChanged;
  final AsyncValue<List<AttendanceLog>> logsAsync;
  final String dateLabel;
  final DateFormat timeFmt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          EmployeeDetailsStrings.attendanceSectionTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          EmployeeDetailsStrings.attendanceSectionSubtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        AttendanceDateFilterBar(
          title: '',
          showTitle: false,
          selectedDay: selectedDay,
          onDateChanged: onDateChanged,
        ),
        const SizedBox(height: 12),
        logsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(e.toString()),
          data: (logs) {
            if (logs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    EmployeeDetailsStrings.noRecordsForDate(dateLabel),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final log in logs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AttendanceLogDetailCard(
                      log: log,
                      showEmployee: false,
                      timeFormat: timeFmt,
                      filterDay: selectedDay,
                      useDateAsTitle: true,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
