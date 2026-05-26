import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_sync_result.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_sync_repository.dart';

class SyncEmployeesUseCase extends UseCase<EmployeeSyncResult, NoParams> {
  SyncEmployeesUseCase(this._repository);

  final EmployeeSyncRepository _repository;

  @override
  Future<Either<Failure, EmployeeSyncResult>> call(NoParams params) {
    return _repository.syncEmployeesFromServer();
  }
}
