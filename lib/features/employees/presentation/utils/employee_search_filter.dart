import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

/// Case-insensitive name / department filter for the employee roster.
abstract final class EmployeeSearchFilter {
  static List<Employee> apply(List<Employee> employees, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return employees;

    return employees
        .where((e) {
          final name = e.name.toLowerCase();
          final department = e.department.toLowerCase();
          return name.contains(query) || department.contains(query);
        })
        .toList(growable: false);
  }
}
