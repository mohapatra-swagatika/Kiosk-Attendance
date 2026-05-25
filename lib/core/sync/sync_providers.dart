import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/api/employee_api.dart';
import 'package:attendance_kiosk_app/core/api/http_kiosk_employee_snapshot_api.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_employee_snapshot_api.dart';
import 'package:attendance_kiosk_app/core/api/mock_employee_api.dart';
import 'package:attendance_kiosk_app/core/api/http_registration_api.dart';
import 'package:attendance_kiosk_app/core/api/registration_api.dart';
import 'package:attendance_kiosk_app/core/sync/data/sync_metadata_local_data_source.dart';
import 'package:attendance_kiosk_app/core/sync/data/sync_queue_local_data_source.dart';
import 'package:attendance_kiosk_app/core/sync/data/sync_repository_impl.dart';
import 'package:attendance_kiosk_app/core/sync/domain/sync_repository.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

final registrationApiProvider = Provider<RegistrationApi>((ref) {
  return const HttpRegistrationApi();
});

final employeeApiProvider = Provider<EmployeeApi>((ref) {
  return const MockEmployeeApi();
});

final kioskEmployeeSnapshotApiProvider = Provider<KioskEmployeeSnapshotApi>((ref) {
  return const HttpKioskEmployeeSnapshotApi();
});

final syncQueueLocalDataSourceProvider = Provider<SyncQueueLocalDataSource>((ref) {
  return SyncQueueLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final syncMetadataLocalDataSourceProvider =
    Provider<SyncMetadataLocalDataSource>((ref) {
  return SyncMetadataLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepositoryImpl(
    ref.watch(syncQueueLocalDataSourceProvider),
    ref.watch(syncMetadataLocalDataSourceProvider),
  );
});
