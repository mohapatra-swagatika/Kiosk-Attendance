import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/widgets/dashboard/dashboard_hero_header.dart';
import 'package:attendance_kiosk_app/features/auth/login/presentation/providers/login_providers.dart';
import 'package:attendance_kiosk_app/features/employee_portal/presentation/providers/employee_portal_providers.dart';
import 'package:attendance_kiosk_app/features/employee_portal/presentation/pages/employee_attendance_capture_page.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

/// Employee dashboard: profile summary, today's status, check-in/out.
class EmployeeDashboardPage extends ConsumerWidget {
  const EmployeeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);
    final employeeAsync = ref.watch(sessionEmployeeProvider);
    final activeAsync = ref.watch(employeeActiveCheckInProvider);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (session) {
        if (session == null || !session.loggedIn || session.employeeId == null) {
          return const Center(child: Text(EmployeePortalStrings.sessionMissing));
        }

        return employeeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (employee) {
            if (employee == null) {
              return const Center(child: Text(EmployeePortalStrings.sessionMissing));
            }

            final hasActive = activeAsync.valueOrNull != null;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      employee.imageUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, size: 72),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DashboardHeroHeader(
                  eyebrow: EmployeePortalStrings.dashboardTab,
                  title: employee.name,
                  subtitle: EmployeePortalStrings.dashboardSubtitle,
                ),
                const SizedBox(height: 20),
                _EmployeeDetailsCard(employee: employee),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      EmployeePortalStrings.todayAttendance,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasActive
                          ? EmployeePortalStrings.statusCheckedIn
                          : EmployeePortalStrings.statusNotCheckedIn,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: hasActive
                          ? null
                          : () => _startCapture(context, employee, isCheckOut: false),
                      icon: const Icon(Icons.login),
                      label: const Text(MatchDialogStrings.checkIn),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: hasActive
                          ? () => _startCapture(context, employee, isCheckOut: true)
                          : null,
                      icon: const Icon(Icons.logout),
                      label: const Text(MatchDialogStrings.checkOut),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      EmployeePortalStrings.offlineHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startCapture(
    BuildContext context,
    Employee employee, {
    required bool isCheckOut,
  }) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmployeeAttendanceCapturePage(
          employee: employee,
          isCheckOut: isCheckOut,
        ),
        fullscreenDialog: true,
      ),
    );
    if (!context.mounted || ok != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCheckOut
              ? MatchDialogStrings.checkOutRecorded
              : MatchDialogStrings.checkInRecorded,
        ),
      ),
    );
  }
}

class _EmployeeDetailsCard extends StatelessWidget {
  const _EmployeeDetailsCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                employee.imageUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    EmployeePortalStrings.detailsTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _detailRow(
                    context,
                    EmployeeCardStrings.idTag(
                      employee.employeeCode?.isNotEmpty == true
                          ? employee.employeeCode!
                          : employee.id,
                    ),
                    employee.employeeCode?.isNotEmpty == true
                        ? employee.employeeCode!
                        : employee.id,
                  ),
                  _detailRow(context, EmployeePortalStrings.departmentLabel, employee.department),
                  _detailRow(
                    context,
                    EmployeePortalStrings.faceLabel,
                    employee.faceRegistered
                        ? EmployeeCardStrings.faceRegistered
                        : EmployeeCardStrings.faceNotConfigured,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
