import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_repository.dart';

class SeedEmployeesParams {
  const SeedEmployeesParams(this.defaults);
  final List<Employee> defaults;
}

/// Seeds local storage when empty (dummy data for kiosk demos).
class SeedEmployeesIfEmptyUseCase extends UseCase<void, SeedEmployeesParams> {
  SeedEmployeesIfEmptyUseCase(this._repository);

  final EmployeeRepository _repository;

  @override
  Future<Either<Failure, void>> call(SeedEmployeesParams params) async {
    final eitherList = await _repository.getEmployees();
    switch (eitherList) {
      case Left(:final value):
        return Left(value);
      case Right(:final value):
        if (value.isNotEmpty) return const Right(null);
        return _repository.replaceAll(params.defaults);
    }
  }
}
