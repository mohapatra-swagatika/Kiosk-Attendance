import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/face_data_sync/data/api/http_kiosk_face_data_api.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/api/kiosk_face_data_api.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/datasources/face_data_queue_local_data_source.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/datasources/face_data_sync_metadata_local_data_source.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/repositories/face_data_sync_repository_impl.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/domain/repositories/face_data_sync_repository.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_events_providers.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

final kioskFaceDataApiProvider = Provider<KioskFaceDataApi>((ref) {
  return const HttpKioskFaceDataApi();
});

final faceDataQueueLocalDataSourceProvider =
    Provider<FaceDataQueueLocalDataSource>((ref) {
  return FaceDataQueueLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final faceDataSyncMetadataLocalDataSourceProvider =
    Provider<FaceDataSyncMetadataLocalDataSource>((ref) {
  return FaceDataSyncMetadataLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final faceDataSyncRepositoryProvider = Provider<FaceDataSyncRepository>((ref) {
  return FaceDataSyncRepositoryImpl(
    ref.watch(faceDataQueueLocalDataSourceProvider),
    ref.watch(kioskConfigLocalDataSourceProvider),
    ref.watch(kioskFaceDataApiProvider),
    ref.watch(networkConnectivityProvider),
    ref.watch(faceDataSyncMetadataLocalDataSourceProvider),
  );
});

final faceDataSyncPendingCountProvider = FutureProvider<int>((ref) async {
  final result = await ref.read(faceDataSyncRepositoryProvider).pendingCount();
  return result.fold((_) => 0, (c) => c);
});

final faceDataSyncLastSyncProvider = FutureProvider<DateTime?>((ref) async {
  final result =
      await ref.read(faceDataSyncRepositoryProvider).lastSuccessfulSyncAt();
  return result.fold((_) => null, (t) => t);
});

/// Combined pending count for attendance events + face data uploads.
final offlineSyncPendingCountProvider = FutureProvider<int>((ref) async {
  final events = await ref.watch(kioskEventsPendingCountProvider.future);
  final face = await ref.watch(faceDataSyncPendingCountProvider.future);
  return events + face;
});
