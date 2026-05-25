import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

abstract class EmployeeRepository {
  Future<Either<Failure, List<Employee>>> getEmployees();

  Future<Either<Failure, void>> replaceAll(List<Employee> employees);

  /// Upserts by [Employee.id] and persists to local storage (Hive).
  Future<Either<Failure, void>> saveEmployee(Employee employee);

  /// Pull roster from server (mock API) and merge local face flags.
  Future<Either<Failure, int>> syncFromServer({required String domain});
}
