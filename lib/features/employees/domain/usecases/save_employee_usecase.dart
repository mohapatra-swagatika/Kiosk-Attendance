import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_repository.dart';

/// Persists a single employee (upsert by id) to local storage.
class SaveEmployeeUseCase extends UseCase<void, Employee> {
  SaveEmployeeUseCase(this._repository);

  final EmployeeRepository _repository;

  @override
  Future<Either<Failure, void>> call(Employee params) {
    return _repository.saveEmployee(params);
  }
}
