import 'dart:io';

import 'package:camera/camera.dart';

import 'package:attendance_kiosk_app/core/camera/camera_session_helper.dart';
import 'package:attendance_kiosk_app/core/storage/attendance_photo_store.dart';

/// Captures a kiosk attendance selfie from the live front camera (check-in/out).
class KioskAttendancePhotoCapture {
  const KioskAttendancePhotoCapture();

  Future<String?> capture({
    required CameraController? controller,
    required String employeeId,
    required bool isCheckOut,
  }) async {
    final camera = controller;
    if (camera == null || !camera.value.isInitialized) return null;
    try {
      final file = await CameraSessionHelper.takeStillPicture(camera);
      if (file == null) return null;
      return const AttendancePhotoStore().saveFromFile(
        source: File(file.path),
        employeeId: employeeId,
        isCheckOut: isCheckOut,
      );
    } catch (_) {
      return null;
    }
  }
}
