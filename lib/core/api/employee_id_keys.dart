/// Canonical employee id field order for kiosk sync/snapshot payloads.
abstract final class EmployeeIdKeys {
  EmployeeIdKeys._();

  /// Prefer stable HR / user ids before display codes when both are present.
  static const primary = [
    'employeeId',
    'employee_id',
    'userId',
    'user_id',
    'uuid',
    '_id',
    'id',
    'empCode',
    'emp_code',
    'employeeCode',
    'employee_code',
    'code',
  ];

  static const aliases = [
    'employeeId',
    'employee_id',
    'userId',
    'user_id',
    'uuid',
    '_id',
    'id',
    'empCode',
    'emp_code',
    'employeeCode',
    'employee_code',
    'code',
  ];
}
