import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

abstract class AttendanceRepository {
  Future<Either<Failure, List<AttendanceLog>>> getAllLogs();
  Future<Either<Failure, List<AttendanceLog>>> getLogsForEmployee(String employeeId);
  Future<Either<Failure, AttendanceLog?>> getActiveCheckIn(String employeeId);
  Future<Either<Failure, AttendanceLog>> checkIn(
    Employee employee, {
    String? photoPath,
  });

  Future<Either<Failure, AttendanceLog>> checkOut(
    Employee employee, {
    String? photoPath,
  });
}
