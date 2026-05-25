import 'package:fpdart/fpdart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:attendance_kiosk_app/core/device/device_id_service.dart';
import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/sync/data/sync_repository_impl.dart';
import 'package:attendance_kiosk_app/core/sync/domain/sync_queue_item.dart';
import 'package:attendance_kiosk_app/core/sync/domain/sync_repository.dart';
import 'package:attendance_kiosk_app/features/attendance/data/datasources/attendance_log_local_data_source.dart';
import 'package:attendance_kiosk_app/features/attendance/data/models/attendance_log_model.dart';
import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(this._local, this._deviceId, this._sync);

  final AttendanceLogLocalDataSource _local;
  final DeviceIdService _deviceId;
  final SyncRepository _sync;
  static const _uuid = Uuid();
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  Future<Either<Failure, List<AttendanceLog>>> getAllLogs() async {
    try {
      final models = await _local.readAll();
      final logs = models.map((m) => m.toEntity()).toList()
        ..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      return Right(logs);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AttendanceLog>>> getLogsForEmployee(String employeeId) async {
    final all = await getAllLogs();
    return all.map((list) => list.where((l) => l.employeeId == employeeId).toList());
  }

  @override
  Future<Either<Failure, AttendanceLog?>> getActiveCheckIn(String employeeId) async {
    final today = _dateFmt.format(DateTime.now());
    final all = await getAllLogs();
    return all.map((list) {
      for (final log in list) {
        if (log.employeeId == employeeId && log.date == today && log.isActiveCheckIn) {
          return log;
        }
      }
      return null;
    });
  }

  @override
  Future<Either<Failure, AttendanceLog>> checkIn(
    Employee employee, {
    String? photoPath,
  }) async {
    try {
      final activeEither = await getActiveCheckIn(employee.id);
      final hasActive = activeEither.fold((_) => false, (a) => a != null);
      if (hasActive) {
        return const Left(ValidationFailure('Employee already checked in. Check out first.'));
      }

      final device = await _deviceId.getOrCreate();
      final now = DateTime.now();
      final log = AttendanceLog(
        id: _uuid.v4(),
        employeeId: employee.id,
        employeeName: employee.name,
        checkInTime: now,
        date: _dateFmt.format(now),
        deviceId: device,
        status: AttendanceStatus.checkedIn,
        checkInPhotoPath: photoPath,
      );

      final models = await _local.readAll();
      models.add(AttendanceLogModel.fromEntity(log));
      await _local.writeAll(models);
      await _sync.enqueue(
        SyncRepositoryImpl.attendanceItem(
          type: SyncQueueTypes.attendanceCheckIn,
          payload: AttendanceLogModel.fromEntity(log).toJson(),
        ),
      );
      return Right(log);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, AttendanceLog>> checkOut(
    Employee employee, {
    String? photoPath,
  }) async {
    try {
      final activeEither = await getActiveCheckIn(employee.id);
      return await activeEither.fold(
        (l) async => Left(l),
        (active) async {
          if (active == null) {
            return const Left(ValidationFailure('No active check-in found for today.'));
          }
          final now = DateTime.now();
          final updated = active.copyWith(
            checkOutTime: now,
            status: AttendanceStatus.checkedOut,
            checkOutPhotoPath: photoPath,
          );
          final models = await _local.readAll();
          final idx = models.indexWhere((m) => m.id == active.id);
          if (idx >= 0) {
            models[idx] = AttendanceLogModel.fromEntity(updated);
            await _local.writeAll(models);
          }
          await _sync.enqueue(
            SyncRepositoryImpl.attendanceItem(
              type: SyncQueueTypes.attendanceCheckOut,
              payload: AttendanceLogModel.fromEntity(updated).toJson(),
            ),
          );
          return Right(updated);
        },
      );
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
