import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/sync/data/sync_metadata_local_data_source.dart';
import 'package:attendance_kiosk_app/core/sync/domain/sync_queue_item.dart';

abstract class SyncRepository {
  Future<Either<Failure, void>> enqueue(SyncQueueItem item);
  Future<Either<Failure, int>> flushPending();
  Future<Either<Failure, SyncMetadata>> metadata();
  Future<Either<Failure, int>> pendingCount();
}
