import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

/// Precomputed lowercase name + department for fast roster search.
final class EmployeeSearchIndexEntry {
  EmployeeSearchIndexEntry(this.employee)
      : _searchText = '${employee.name} ${employee.department}'.toLowerCase();

  final Employee employee;
  final String _searchText;

  bool matches(String queryLower) => _searchText.contains(queryLower);
}

/// Case-insensitive name / department filter for the employee roster.
abstract final class EmployeeSearchFilter {
  static List<EmployeeSearchIndexEntry> buildIndex(List<Employee> employees) {
    return employees.map(EmployeeSearchIndexEntry.new).toList(growable: false);
  }

  /// Filters [index] built from [fullRoster]. Returns [fullRoster] when query is empty.
  static List<Employee> applyIndex(
    List<Employee> fullRoster,
    List<EmployeeSearchIndexEntry> index,
    String rawQuery,
  ) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return fullRoster;

    return [
      for (final entry in index)
        if (entry.matches(query)) entry.employee,
    ];
  }

  static List<Employee> apply(List<Employee> employees, String rawQuery) {
    return applyIndex(employees, buildIndex(employees), rawQuery);
  }
}
