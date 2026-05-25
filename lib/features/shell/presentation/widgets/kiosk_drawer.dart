import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_kiosk_app/app/router/route_paths.dart';
import 'package:attendance_kiosk_app/app/router/router_refresh.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/auth/login/presentation/providers/login_providers.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_branding_header.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/sync_status_footer.dart';

class KioskDrawer extends StatelessWidget {
  const KioskDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(child: KioskDrawerContent());
  }
}

class KioskDrawerContent extends ConsumerWidget {
  const KioskDrawerContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);
    final session = sessionAsync.valueOrNull;
    final isAdmin = session?.isAdmin ?? false;
    final scheme = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).matchedLocation;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KioskBrandingHeader(compact: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session?.displayName ?? AppStrings.menu,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (session != null)
                  Text(
                    isAdmin ? DrawerStrings.adminRole : DrawerStrings.employeeRole,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isAdmin) ...[
            _tile(
              context,
              icon: Icons.dashboard_rounded,
              label: AppStrings.home,
              path: RoutePaths.home,
              selected: location == RoutePaths.home,
            ),
            _tile(
              context,
              icon: Icons.groups_rounded,
              label: AppStrings.employees,
              path: RoutePaths.employees,
              selected: RoutePaths.isEmployeesArea(location),
            ),
            _tile(
              context,
              icon: Icons.fact_check_rounded,
              label: AppStrings.attendance,
              path: RoutePaths.attendance,
              selected: location == RoutePaths.attendance,
            ),
            _tile(
              context,
              icon: Icons.settings_outlined,
              label: KioskSidebarStrings.settings,
              path: RoutePaths.settings,
              selected: location == RoutePaths.settings,
            ),
          ] else ...[
            _tile(
              context,
              icon: Icons.dashboard_rounded,
              label: EmployeePortalStrings.dashboardTab,
              path: RoutePaths.employeeHome,
              selected: location == RoutePaths.employeeHome,
            ),
            _tile(
              context,
              icon: Icons.fact_check_rounded,
              label: EmployeePortalStrings.attendanceTab,
              path: RoutePaths.employeeAttendance,
              selected: location == RoutePaths.employeeAttendance,
            ),
          ],
          const Spacer(),
          if (isAdmin) const SyncStatusFooter(),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: Text(AppStrings.signOut),
            onTap: () async {
              await ref.read(logoutUseCaseProvider)(const NoParams());
              ref.invalidate(appSessionProvider);
              ref.read(routerRefreshProvider).notify();
              if (context.mounted) context.go(RoutePaths.kiosk);
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String path,
    required bool selected,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: () {
        Navigator.of(context).maybePop();
        context.go(path);
      },
    );
  }
}
