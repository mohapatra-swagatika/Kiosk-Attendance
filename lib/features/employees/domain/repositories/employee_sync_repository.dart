import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_sync_result.dart';

abstract class EmployeeSyncRepository {
  Future<Either<Failure, EmployeeSyncResult>> syncEmployeesFromServer();

  Future<Either<Failure, EmployeeSyncMetadata>> getSyncMetadata();
}
