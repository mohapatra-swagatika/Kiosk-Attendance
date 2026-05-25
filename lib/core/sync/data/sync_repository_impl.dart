import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/sync/data/sync_metadata_local_data_source.dart';
import 'package:attendance_kiosk_app/core/sync/data/sync_queue_local_data_source.dart';
import 'package:attendance_kiosk_app/core/sync/domain/sync_queue_item.dart';
import 'package:attendance_kiosk_app/core/sync/domain/sync_repository.dart';
import 'package:attendance_kiosk_app/core/sync/sync_status.dart';

/// Flushes the local outbox via a mock remote (replace with HTTP later).
class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl(this._queue, this._metadata);

  final SyncQueueLocalDataSource _queue;
  final SyncMetadataLocalDataSource _metadata;
  static const _uuid = Uuid();

  @override
  Future<Either<Failure, void>> enqueue(SyncQueueItem item) async {
    try {
      await _queue.enqueue(item);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, int>> pendingCount() async {
    try {
      final all = await _queue.readAll();
      return Right(all.where((e) => e.status == SyncStatus.pending).length);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, SyncMetadata>> metadata() async {
    try {
      return Right(await _metadata.read());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, int>> flushPending() async {
    try {
      final all = await _queue.readAll();
      var synced = 0;
      final updated = <SyncQueueItem>[];

      for (final item in all) {
        if (item.status != SyncStatus.pending) {
          updated.add(item);
          continue;
        }
        await Future<void>.delayed(const Duration(milliseconds: 120));
        updated.add(item.copyWith(status: SyncStatus.synced));
        synced++;
      }

      await _queue.writeAll(updated);
      await _metadata.write(
        SyncMetadata(lastSyncAt: DateTime.now(), lastSyncError: null),
      );
      return Right(synced);
    } on CacheException catch (e) {
      await _metadata.write(SyncMetadata(lastSyncError: e.message));
      return Left(CacheFailure(e.message));
    }
  }

  /// Helper for attendance events.
  static SyncQueueItem attendanceItem({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    return SyncQueueItem(
      id: _uuid.v4(),
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );
  }
}
