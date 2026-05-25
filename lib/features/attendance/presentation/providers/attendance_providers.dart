import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/features/attendance/data/datasources/attendance_log_local_data_source.dart';
import 'package:attendance_kiosk_app/features/attendance/data/ml/mlkit_face_detection_adapter.dart';
import 'package:attendance_kiosk_app/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/face_profile_local_data_source.dart';
import 'package:attendance_kiosk_app/features/employees/data/repositories/face_repository_impl.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/face_repository.dart';
import 'package:attendance_kiosk_app/core/sync/sync_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

final faceDetectionPortProvider = Provider<FaceDetectionPort>((ref) {
  final adapter = MlKitFaceDetectionAdapter();
  ref.onDispose(adapter.dispose);
  return adapter;
});

final faceProfileLocalDataSourceProvider = Provider<FaceProfileLocalDataSource>((ref) {
  return FaceProfileLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final attendanceLogLocalDataSourceProvider = Provider<AttendanceLogLocalDataSource>((ref) {
  return AttendanceLogLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(
    ref.watch(attendanceLogLocalDataSourceProvider),
    ref.watch(deviceIdServiceProvider),
    ref.watch(syncRepositoryProvider),
  );
});

final faceRepositoryProvider = Provider<FaceRepository>((ref) {
  return FaceRepositoryImpl(
    ref.watch(faceProfileLocalDataSourceProvider),
    ref.watch(employeeRepositoryProvider),
  );
});

final attendanceLogsProvider = FutureProvider<List<AttendanceLog>>((ref) async {
  final result = await ref.read(attendanceRepositoryProvider).getAllLogs();
  return result.fold((l) => throw StateError(l.message), (r) => r);
});

final activeCheckInsTodayProvider = FutureProvider<List<AttendanceLog>>((ref) async {
  final logs = await ref.watch(attendanceLogsProvider.future);
  return logs.where((l) => l.isActiveCheckIn).toList();
});
