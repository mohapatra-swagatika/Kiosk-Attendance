import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/config/attendance_mode.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';

abstract class KioskConfigRepository {
  Future<Either<Failure, void>> save(KioskConfig config);
  Future<Either<Failure, KioskConfig?>> load();
  Future<Either<Failure, bool>> hasConfig();
  Future<Either<Failure, void>> updateAttendanceMode(AttendanceMode mode);
}
