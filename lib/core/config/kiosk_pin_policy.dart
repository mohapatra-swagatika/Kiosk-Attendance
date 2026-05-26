import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

/// Kiosk PIN length and validation rules (admin + employee).
class KioskPinPolicy {
  KioskPinPolicy._();

  static const int length = 7;

  /// Default device admin PIN until the registration API returns `admin_pin`.
  static const String defaultAdminPin = '1838808';

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  static bool isValidFormat(String pin) {
    final normalized = pin.trim();
    return normalized.length == length && _digitsOnly.hasMatch(normalized);
  }

  static String effectiveAdminPin(String? storedAdminPin) {
    final stored = storedAdminPin?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return defaultAdminPin;
  }

  /// Device-level admin PIN from kiosk pairing (fallback when not in roster).
  static bool isDeviceAdminPin(String pin, String? storedAdminPin) {
    return pin.trim() == effectiveAdminPin(storedAdminPin);
  }

  static String maskedDisplay(String pin) {
    if (pin.isEmpty) return '•' * length;
    return '•' * pin.length;
  }

  /// Finds a synced employee whose kiosk PIN exactly matches [pin].
  static Employee? findEmployeeByPin(List<Employee> employees, String pin) {
    final normalized = pin.trim();
    if (!isValidFormat(normalized)) return null;

    for (final employee in employees) {
      final employeePin = employee.pin.trim();
      if (employeePin.isNotEmpty && employeePin == normalized) {
        return employee;
      }
    }
    return null;
  }

  /// @deprecated Use [findEmployeeByPin].
  static Employee? resolveEmployee(List<Employee> employees, String pin) =>
      findEmployeeByPin(employees, pin);
}
