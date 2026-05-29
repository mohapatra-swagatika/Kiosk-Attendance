import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/api/mock_employee_roster.dart';
import 'package:attendance_kiosk_app/features/employees/data/employee_snapshot_store.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/employee_local_data_source.dart';
import 'package:attendance_kiosk_app/features/employees/data/repositories/employee_repository_impl.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_repository.dart';
import 'package:attendance_kiosk_app/features/employees/domain/usecases/get_employees_usecase.dart';
import 'package:attendance_kiosk_app/features/employees/domain/usecases/save_employee_usecase.dart';
import 'package:attendance_kiosk_app/features/employees/domain/usecases/seed_employees_if_empty_usecase.dart';
import 'package:attendance_kiosk_app/core/sync/sync_providers.dart';
import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_filter_providers.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

final employeeLocalDataSourceProvider = Provider<EmployeeLocalDataSource>((ref) {
  return EmployeeLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl(
    ref.watch(employeeLocalDataSourceProvider),
    ref.watch(employeeApiProvider),
  );
});

final employeeSnapshotStoreProvider = Provider<EmployeeSnapshotStore>((ref) {
  return EmployeeSnapshotStore(
    ref.watch(kioskEmployeeSnapshotApiProvider),
    ref.watch(employeeRepositoryProvider),
    ref.watch(faceRepositoryProvider),
  );
});

final getEmployeesUseCaseProvider = Provider<GetEmployeesUseCase>((ref) {
  return GetEmployeesUseCase(ref.watch(employeeRepositoryProvider));
});

final seedEmployeesIfEmptyUseCaseProvider = Provider<SeedEmployeesIfEmptyUseCase>((ref) {
  return SeedEmployeesIfEmptyUseCase(ref.watch(employeeRepositoryProvider));
});

final defaultDummyEmployeesProvider = Provider<List<Employee>>((ref) {
  return MockEmployeeRoster.employees();
});

final saveEmployeeUseCaseProvider = Provider<SaveEmployeeUseCase>((ref) {
  return SaveEmployeeUseCase(ref.watch(employeeRepositoryProvider));
});

final employeesListProvider = FutureProvider<List<Employee>>((ref) async {
  final kioskConfig = await ref.watch(kioskConfigProvider.future);
  final isPairedKiosk = kioskConfig?.deviceId?.trim().isNotEmpty == true;
  if (!isPairedKiosk) {
    final seed = ref.read(seedEmployeesIfEmptyUseCaseProvider);
    await seed(SeedEmployeesParams(ref.read(defaultDummyEmployeesProvider)));
  }
  // Reconcile face flags after the roster is shown — never during registration.
  if (isPairedKiosk) {
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 2),
        () => ref.read(faceRepositoryProvider).reconcileFaceRegistrationFlags(),
      ),
    );
  }
  final get = ref.read(getEmployeesUseCaseProvider);
  final result = await get(const NoParams());
  return result.fold((l) => throw StateError(l.message), (r) => r);
});

/// True when this employee has an on-device face profile.
final employeeHasFaceEmbeddingProvider = FutureProvider.family<bool, String>((ref, employeeId) async {
  final result = await ref.read(faceRepositoryProvider).hasRegisteredFace(employeeId);
  return result.fold((_) => false, (v) => v);
});

final employeeByIdProvider = FutureProvider.family<Employee?, String>((ref, id) async {
  final employees = await ref.watch(employeesListProvider.future);
  final normalized = Uri.decodeComponent(id).trim();
  for (final e in employees) {
    if (e.id == normalized) return e;
    final code = e.employeeCode?.trim();
    if (code != null && code.isNotEmpty && code == normalized) return e;
  }
  return null;
});

/// Attendance logs for one employee on a selected calendar day.
final employeeAttendanceLogsForDateProvider =
    FutureProvider.family<List<AttendanceLog>, ({String employeeId, DateTime day})>(
  (ref, params) async {
    final logs = await ref.watch(attendanceLogsForDateProvider(params.day).future);
    return logs.where((l) => l.employeeId == params.employeeId).toList()
      ..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
  },
);
