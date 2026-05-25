import 'package:attendance_kiosk_app/core/api/employee_api.dart';
import 'package:attendance_kiosk_app/core/api/mock_employee_roster.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

/// Mock server roster — merges with local face-registration flags on sync.
class MockEmployeeApi implements EmployeeApi {
  const MockEmployeeApi();

  @override
  Future<List<Employee>> fetchEmployees({required String domain}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return MockEmployeeRoster.employees();
  }
}
