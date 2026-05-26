import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';

abstract class KioskEventsRepository {
  /// Queues a check-in/out event and uploads immediately when online.
  Future<Either<Failure, void>> recordAttendanceEvent({
    required String attendanceLogId,
    required String employeeId,
    required bool isCheckOut,
    required String authMethod,
    required DateTime eventTime,
    String? photoPath,
  });

  /// Uploads all pending/failed events (retries included). Returns count synced.
  ///
  /// When [ignoreConnectivity] is true, attempts HTTP even if connectivity_plus
  /// reports offline (used right after check-in/out).
  Future<Either<Failure, int>> syncPending({bool ignoreConnectivity = false});

  Future<Either<Failure, int>> pendingCount();

  Future<Either<Failure, DateTime?>> lastSuccessfulSyncAt();
}
