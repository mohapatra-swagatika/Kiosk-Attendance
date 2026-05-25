abstract final class RoutePaths {
  static const registration = '/registration';
  static const login = '/login';
  static const home = '/home';
  static const employees = '/employees';
  static const employeeDetail = '/employees/:id';
  static const attendance = '/attendance';
  static const kiosk = '/kiosk';
  static const employeeHome = '/employee';
  static const employeeAttendance = '/employee/attendance';
  static const settings = '/settings';
  static const faceRegister = '/employees/:id/face-register';

  static String employeeDetailPath(String employeeId) => '/employees/$employeeId';

  static String faceRegisterPath(String employeeId) => '/employees/$employeeId/face-register';

  static bool isEmployeesArea(String location) =>
      location == employees || location.startsWith('$employees/');

  static const adminShellRoutes = [home, employees, attendance, settings];
  static const employeeShellRoutes = [employeeHome, employeeAttendance];
}
