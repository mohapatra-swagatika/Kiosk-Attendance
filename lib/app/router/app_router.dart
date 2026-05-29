import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_kiosk_app/app/app_launch_gate.dart';
import 'package:attendance_kiosk_app/app/di/core_providers.dart';
import 'package:attendance_kiosk_app/app/router/route_paths.dart';
import 'package:attendance_kiosk_app/app/router/router_refresh.dart';
import 'package:attendance_kiosk_app/core/auth/user_role.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/pages/attendance_admin_page.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/pages/employee_details_page.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/pages/employees_page.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/pages/face_registration_page.dart';
import 'package:attendance_kiosk_app/features/employee_portal/presentation/pages/employee_attendance_records_page.dart';
import 'package:attendance_kiosk_app/features/employee_portal/presentation/pages/employee_dashboard_page.dart';
import 'package:attendance_kiosk_app/features/home/presentation/pages/home_dashboard_page.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/pages/kiosk_mode_page.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/pages/registration_page.dart';
import 'package:attendance_kiosk_app/features/shell/presentation/pages/kiosk_shell_page.dart';
import 'package:attendance_kiosk_app/features/shell/presentation/pages/settings_page.dart';

Page<void> _noTransitionPage(GoRouterState state, {required Widget child}) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

/// Route guard using preloaded Hive flags (no per-navigation repository round-trips).
String? _redirectForLocation(String loc, GateSnapshot gate) {
  final has = gate.hasConfig;
  final session = gate.session;
  final auth = gate.loggedIn;
  final role = session?.role ?? UserRole.employee;

  final isRegistration = loc == RoutePaths.registration;
  final isLogin = loc == RoutePaths.login;
  final isAdminRoute =
      RoutePaths.adminShellRoutes.contains(loc) || RoutePaths.isEmployeesArea(loc);
  final isEmployeeRoute = RoutePaths.employeeShellRoutes.contains(loc);
  final isFaceRegister = loc.contains('/face-register');

  if (!has && !isRegistration) {
    return RoutePaths.registration;
  }

  if (has && isRegistration) {
    if (auth) {
      return role == UserRole.admin ? RoutePaths.home : RoutePaths.employeeHome;
    }
    return RoutePaths.kiosk;
  }

  if (has && isLogin) {
    return RoutePaths.kiosk;
  }

  if (has && !auth && (isAdminRoute || isEmployeeRoute || isFaceRegister)) {
    return RoutePaths.kiosk;
  }

  if (has && auth && role == UserRole.admin && isEmployeeRoute) {
    return RoutePaths.home;
  }

  if (has && auth && role == UserRole.employee && isAdminRoute) {
    return RoutePaths.employeeHome;
  }

  if (has && auth && role == UserRole.employee && loc == RoutePaths.settings) {
    return RoutePaths.employeeHome;
  }

  return null;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);
  final config = ref.watch(appConfigProvider);
  final initialLocation =
      AppLaunchGate.isCached && AppLaunchGate.cached.hasConfig
          ? RoutePaths.kiosk
          : RoutePaths.registration;
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refresh,
    debugLogDiagnostics: config.enableVerboseLogs,
    redirect: (context, state) async {
      if (AppLaunchGate.isCached) {
        return _redirectForLocation(state.matchedLocation, AppLaunchGate.cached);
      }
      if (!AppLaunchGate.isStorageReady) {
        return null;
      }
      final gate = await AppLaunchGate.read();
      return _redirectForLocation(state.matchedLocation, gate);
    },
    routes: [
      GoRoute(
        path: RoutePaths.registration,
        pageBuilder: (context, state) =>
            _noTransitionPage(state, child: const RegistrationPage()),
      ),
      GoRoute(
        path: RoutePaths.login,
        redirect: (context, state) => RoutePaths.kiosk,
      ),
      GoRoute(
        path: RoutePaths.kiosk,
        pageBuilder: (context, state) =>
            _noTransitionPage(state, child: const KioskModePage()),
      ),
      GoRoute(
        path: RoutePaths.faceRegister,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _noTransitionPage(
            state,
            child: FaceRegistrationPage(employeeId: id),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => KioskShellPage(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.home,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, child: const HomeDashboardPage()),
          ),
          GoRoute(
            path: RoutePaths.employees,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, child: const EmployeesPage()),
          ),
          GoRoute(
            path: RoutePaths.employeeDetail,
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              final extra = state.extra;
              return _noTransitionPage(
                state,
                child: EmployeeDetailsPage(
                  employeeId: id,
                  initialEmployee: extra is Employee ? extra : null,
                ),
              );
            },
          ),
          GoRoute(
            path: RoutePaths.attendance,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, child: const AttendanceAdminPage()),
          ),
          GoRoute(
            path: RoutePaths.employeeHome,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, child: const EmployeeDashboardPage()),
          ),
          GoRoute(
            path: RoutePaths.employeeAttendance,
            pageBuilder: (context, state) => _noTransitionPage(
              state,
              child: const EmployeeAttendanceRecordsPage(),
            ),
          ),
          GoRoute(
            path: RoutePaths.settings,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, child: const SettingsPage()),
          ),
        ],
      ),
    ],
  );
});
