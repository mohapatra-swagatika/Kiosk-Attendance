import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/core/widgets/app_error_view.dart';
import 'package:attendance_kiosk_app/core/widgets/app_loading.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/widgets/employee_card.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_kiosk_app/app/router/route_paths.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

/// Employee roster from local Hive storage with tablet-responsive cards.
class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key});

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  bool _syncing = false;

  Future<void> _syncEmployees() async {
    final config = await ref.read(kioskConfigProvider.future);
    final domain = config?.domain ?? '';
    if (domain.isEmpty) return;

    setState(() => _syncing = true);
    final result = config!.deviceId != null &&
            config.deviceId!.isNotEmpty &&
            config.deviceToken != null &&
            config.deviceToken!.isNotEmpty
        ? await ref.read(employeeSnapshotStoreProvider).fetchAndStoreForConfig(config)
        : await ref.read(employeeRepositoryProvider).syncFromServer(
              domain: config.domain,
            );
    if (!mounted) return;
    setState(() => _syncing = false);

    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
      (count) async {
        ref.invalidate(employeesListProvider);
        await ref.read(faceRepositoryProvider).preloadGallery();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(EmployeesStrings.syncedCount(count))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(employeesListProvider);

    return async.when(
      data: (employees) {
        if (employees.isEmpty) {
          return const Center(child: Text(EmployeesStrings.empty));
        }
        return ResponsiveBuilder(
          builder: (context, bp, constraints) {
            final crossCount = switch (bp) {
              AppBreakpointSize.compact => 1,
              AppBreakpointSize.medium => 2,
              AppBreakpointSize.expanded => 3,
            };
            final pad = switch (bp) {
              AppBreakpointSize.compact => 16.0,
              AppBreakpointSize.medium => 24.0,
              AppBreakpointSize.expanded => 28.0,
            };
            const gridSpacing = 16.0;
            final contentWidth = constraints.maxWidth - pad * 2;
            final itemWidth = crossCount <= 1
                ? contentWidth
                : (contentWidth - gridSpacing * (crossCount - 1)) / crossCount;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(EmployeesStrings.title, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text(
                          EmployeesStrings.subtitle,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            onPressed: _syncing ? null : _syncEmployees,
                            icon: _syncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.cloud_download_outlined),
                            label: Text(EmployeesStrings.syncEmployees),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, pad + 24),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: gridSpacing,
                      runSpacing: gridSpacing,
                      children: [
                        for (final e in employees)
                          SizedBox(
                            width: itemWidth,
                            child: EmployeeCard(
                              employee: e,
                              compact: crossCount == 1,
                              onViewDetails: () => context.push(
                                RoutePaths.employeeDetailPath(e.id),
                                extra: e,
                              ),
                            ),
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
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorView(message: e.toString(), onRetry: () => ref.invalidate(employeesListProvider)),
    );
  }
}
