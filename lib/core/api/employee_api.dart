import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

/// Pull employee roster from server — replace mock with REST client later.
abstract class EmployeeApi {
  Future<List<Employee>> fetchEmployees({required String domain});
}
