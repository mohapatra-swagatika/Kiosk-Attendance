import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/device/device_id_service.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';
import 'package:attendance_kiosk_app/features/registration/data/datasources/kiosk_config_local_data_source.dart';
import 'package:attendance_kiosk_app/features/registration/data/repositories/kiosk_config_repository_impl.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';
import 'package:attendance_kiosk_app/features/registration/domain/repositories/kiosk_config_repository.dart';
import 'package:attendance_kiosk_app/features/registration/domain/usecases/has_kiosk_config_usecase.dart';
import 'package:attendance_kiosk_app/core/sync/sync_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/registration/domain/usecases/register_kiosk_usecase.dart';

final appBoxProvider = Provider<Box<dynamic>>((ref) {
  return Hive.box<dynamic>(HiveBoxes.app);
});

final kioskConfigLocalDataSourceProvider = Provider<KioskConfigLocalDataSource>((ref) {
  return KioskConfigLocalDataSourceImpl(ref.watch(appBoxProvider));
});

/// Stable device id for attendance — overwritten with server `deviceId` after pair.
final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return DeviceIdService(ref.watch(appBoxProvider));
});

final kioskConfigRepositoryProvider = Provider<KioskConfigRepository>((ref) {
  return KioskConfigRepositoryImpl(
    ref.watch(kioskConfigLocalDataSourceProvider),
    ref.watch(registrationApiProvider),
    deviceIdService: ref.watch(deviceIdServiceProvider),
    employeeSnapshotStore: ref.watch(employeeSnapshotStoreProvider),
  );
});

final registerKioskUseCaseProvider = Provider<RegisterKioskUseCase>((ref) {
  return RegisterKioskUseCase(ref.watch(kioskConfigRepositoryProvider));
});

final hasKioskConfigUseCaseProvider = Provider<HasKioskConfigUseCase>((ref) {
  return HasKioskConfigUseCase(ref.watch(kioskConfigRepositoryProvider));
});

/// Saved device registration (domain, code, machine name, …) from Hive.
/// Branding files are verified/repaired on each load for offline-first display.
final kioskConfigProvider = FutureProvider<KioskConfig?>((ref) async {
  final result = await ref.read(kioskConfigRepositoryProvider).load();
  return result.fold((_) => null, (config) => config);
});
