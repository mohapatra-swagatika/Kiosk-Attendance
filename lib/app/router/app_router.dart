import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_kiosk_app/app/di/core_providers.dart';
import 'package:attendance_kiosk_app/app/router/route_paths.dart';
import 'package:attendance_kiosk_app/app/router/router_refresh.dart';
import 'package:attendance_kiosk_app/core/auth/user_role.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/pages/attendance_admin_page.dart';
import 'package:attendance_kiosk_app/features/auth/login/presentation/providers/login_providers.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/pages/employee_details_page.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/pages/employees_page.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/pages/face_registration_page.dart';
import 'package:attendance_kiosk_app/features/employee_portal/presentation/pages/employee_attendance_records_page.dart';
import 'package:attendance_kiosk_app/features/employee_portal/presentation/pages/employee_dashboard_page.dart';
import 'package:attendance_kiosk_app/features/home/presentation/pages/home_dashboard_page.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/pages/kiosk_mode_page.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/pages/registration_page.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';
import 'package:attendance_kiosk_app/features/shell/presentation/pages/kiosk_shell_page.dart';
import 'package:attendance_kiosk_app/features/shell/presentation/pages/settings_page.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);
  final config = ref.watch(appConfigProvider);
  return GoRouter(
    initialLocation: RoutePaths.kiosk,
    refreshListenable: refresh,
    debugLogDiagnostics: config.enableVerboseLogs,
    redirect: (context, state) async {
      final hasConfigEither =
          await ref.read(hasKioskConfigUseCaseProvider)(const NoParams());
      final sessionEither =
          await ref.read(authRepositoryProvider).currentSession();

      final has = hasConfigEither.fold((_) => false, (v) => v);
      final session = sessionEither.fold((_) => null, (s) => s);
      final auth = session?.loggedIn == true;
      final role = session?.role ?? UserRole.employee;

      final loc = state.matchedLocation;
      final isRegistration = loc == RoutePaths.registration;
      final isLogin = loc == RoutePaths.login;
      final isAdminRoute =
          RoutePaths.adminShellRoutes.contains(loc) ||
          RoutePaths.isEmployeesArea(loc);
      final isEmployeeRoute = RoutePaths.employeeShellRoutes.contains(loc);
      final isFaceRegister = loc.contains('/face-register');

      if (!has && !isRegistration) {
        return RoutePaths.registration;
      }

      if (has && isLogin) {
        return RoutePaths.kiosk;
      }

      if (has && !auth && (isAdminRoute || isEmployeeRoute || isFaceRegister)) {
        return RoutePaths.kiosk;
      }

      if (has && auth && isRegistration) {
        return role == UserRole.admin ? RoutePaths.home : RoutePaths.employeeHome;
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
    },
    routes: [
      GoRoute(
        path: RoutePaths.registration,
        builder: (context, state) => const RegistrationPage(),
      ),
      GoRoute(
        path: RoutePaths.login,
        redirect: (context, state) => RoutePaths.kiosk,
      ),
      GoRoute(
        path: RoutePaths.kiosk,
        builder: (context, state) => const KioskModePage(),
      ),
      GoRoute(
        path: RoutePaths.faceRegister,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FaceRegistrationPage(employeeId: id);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => KioskShellPage(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) => const HomeDashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.employees,
            builder: (context, state) => const EmployeesPage(),
          ),
          GoRoute(
            path: RoutePaths.employeeDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final extra = state.extra;
              return EmployeeDetailsPage(
                employeeId: id,
                initialEmployee: extra is Employee ? extra : null,
              );
            },
          ),
          GoRoute(
            path: RoutePaths.attendance,
            builder: (context, state) => const AttendanceAdminPage(),
          ),
          GoRoute(
            path: RoutePaths.employeeHome,
            builder: (context, state) => const EmployeeDashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.employeeAttendance,
            builder: (context, state) => const EmployeeAttendanceRecordsPage(),
          ),
          GoRoute(
            path: RoutePaths.settings,
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});
