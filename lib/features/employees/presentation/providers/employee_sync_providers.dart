import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/api/http_kiosk_sync_employees_api.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_sync_employees_api.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/employee_sync_metadata_local_data_source.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/employee_sync_remote_data_source.dart';
import 'package:attendance_kiosk_app/features/employees/data/repositories/employee_sync_repository_impl.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_sync_repository.dart';
import 'package:attendance_kiosk_app/features/employees/domain/usecases/sync_employees_usecase.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_sync_result.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_sync_notifier.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

export 'employee_sync_notifier.dart';

final kioskSyncEmployeesApiProvider = Provider<KioskSyncEmployeesApi>((ref) {
  return const HttpKioskSyncEmployeesApi();
});

final employeeSyncRemoteDataSourceProvider =
    Provider<EmployeeSyncRemoteDataSource>((ref) {
  return EmployeeSyncRemoteDataSourceImpl(ref.watch(kioskSyncEmployeesApiProvider));
});

final employeeSyncMetadataLocalDataSourceProvider =
    Provider<EmployeeSyncMetadataLocalDataSource>((ref) {
  return EmployeeSyncMetadataLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final employeeSyncRepositoryProvider = Provider<EmployeeSyncRepository>((ref) {
  return EmployeeSyncRepositoryImpl(
    ref.watch(kioskConfigLocalDataSourceProvider),
    ref.watch(employeeSyncRemoteDataSourceProvider),
    ref.watch(employeeSnapshotStoreProvider),
    ref.watch(employeeSyncMetadataLocalDataSourceProvider),
  );
});

final syncEmployeesUseCaseProvider = Provider<SyncEmployeesUseCase>((ref) {
  return SyncEmployeesUseCase(ref.watch(employeeSyncRepositoryProvider));
});

final employeeSyncNotifierProvider =
    StateNotifierProvider<EmployeeSyncNotifier, EmployeeSyncUiState>((ref) {
  return EmployeeSyncNotifier(
    ref.watch(syncEmployeesUseCaseProvider),
    () async {
      final result =
          await ref.read(employeeSyncRepositoryProvider).getSyncMetadata();
      return result.fold((_) => const EmployeeSyncMetadata(), (m) => m);
    },
  );
});
