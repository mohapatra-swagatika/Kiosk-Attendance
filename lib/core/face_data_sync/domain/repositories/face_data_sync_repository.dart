import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';

abstract class FaceDataSyncRepository {
  /// Queues face profile for upload and attempts immediate sync when online.
  ///
  /// Returns false when an identical payload is already pending/synced.
  Future<Either<Failure, bool>> enqueueAndSync({
    required String employeeId,
    required Map<String, dynamic> faceDataJson,
  });

  Future<Either<Failure, int>> syncPending({bool ignoreConnectivity = false});

  Future<Either<Failure, int>> pendingCount();

  Future<Either<Failure, DateTime?>> lastSuccessfulSyncAt();

  /// Queues `faceDataJson: {}` to clear server face data (same API as enroll upload).
  Future<Either<Failure, bool>> enqueueClearAndSync({required String employeeId});

  /// Drops pending/failed uploads for [employeeId] without uploading a clear payload.
  Future<Either<Failure, void>> removePendingForEmployee(String employeeId);
}
