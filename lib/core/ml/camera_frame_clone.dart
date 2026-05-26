import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/features/attendance/data/ml/camera_frame_converter.dart';

/// Deep copy of one camera frame so native buffers are not used after async gaps.
///
/// iOS recycles [CameraImage] plane memory as soon as the stream callback returns;
/// reading planes after `await` causes EXC_BAD_ACCESS.
class CameraFrameClone {
  CameraFrameClone({
    required this.frame,
    required this.description,
    required this.orientation,
  });

  final LiveCameraFrame frame;
  final CameraDescription description;
  final DeviceOrientation orientation;

  /// Synchronous copy — call at the top of the image-stream callback.
  static CameraFrameClone? fromCameraImage({
    required CameraImage image,
    required CameraDescription description,
    required DeviceOrientation orientation,
  }) {
    final live = liveFrameFromCameraImage(
      image: image,
      description: description,
      deviceOrientation: orientation,
    );
    if (live == null) return null;

    return CameraFrameClone(
      frame: LiveCameraFrame(
        bytes: _fastCopyBytes(live.bytes),
        width: live.width,
        height: live.height,
        rotationDegrees: live.rotationDegrees,
        format: live.format,
        bytesPerRow: live.bytesPerRow,
      ),
      description: description,
      orientation: orientation,
    );
  }

  /// Slightly faster than [Uint8List.fromList] on large NV21 buffers (Android).
  static Uint8List _fastCopyBytes(Uint8List src) {
    final out = Uint8List(src.length);
    out.setAll(0, src);
    return out;
  }
}
