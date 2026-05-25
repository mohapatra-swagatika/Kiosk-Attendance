import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_repository.dart';

class GetEmployeesUseCase extends UseCase<List<Employee>, NoParams> {
  GetEmployeesUseCase(this._repository);

  final EmployeeRepository _repository;

  @override
  Future<Either<Failure, List<Employee>>> call(NoParams params) {
    return _repository.getEmployees();
  }
}
