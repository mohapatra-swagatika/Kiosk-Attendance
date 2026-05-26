import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/kiosk_events/data/api/http_kiosk_bulk_events_api.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/data/api/kiosk_bulk_events_api.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/data/datasources/kiosk_events_queue_local_data_source.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/data/repositories/kiosk_events_repository_impl.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/domain/repositories/kiosk_events_repository.dart';
import 'package:attendance_kiosk_app/core/network/network_connectivity.dart';
import 'package:attendance_kiosk_app/core/sync/sync_providers.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

final kioskBulkEventsApiProvider = Provider<KioskBulkEventsApi>((ref) {
  return const HttpKioskBulkEventsApi();
});

final networkConnectivityProvider = Provider<NetworkConnectivity>((ref) {
  return NetworkConnectivity();
});

final kioskEventsQueueLocalDataSourceProvider =
    Provider<KioskEventsQueueLocalDataSource>((ref) {
  return KioskEventsQueueLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final kioskEventsRepositoryProvider = Provider<KioskEventsRepository>((ref) {
  return KioskEventsRepositoryImpl(
    ref.watch(kioskEventsQueueLocalDataSourceProvider),
    ref.watch(kioskConfigLocalDataSourceProvider),
    ref.watch(kioskBulkEventsApiProvider),
    ref.watch(networkConnectivityProvider),
    syncMetadata: ref.watch(syncMetadataLocalDataSourceProvider),
  );
});

final kioskEventsPendingCountProvider = FutureProvider<int>((ref) async {
  final result = await ref.read(kioskEventsRepositoryProvider).pendingCount();
  return result.fold((_) => 0, (c) => c);
});

final kioskEventsLastSyncProvider = FutureProvider<DateTime?>((ref) async {
  final result =
      await ref.read(kioskEventsRepositoryProvider).lastSuccessfulSyncAt();
  return result.fold((_) => null, (t) => t);
});
