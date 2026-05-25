import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'package:attendance_kiosk_app/core/camera/camera_runtime.dart';

/// Opens the front camera and returns a controller after [CameraController.initialize].
///
/// Call [startImageStreamAfterPreview] so the preview paints before ML Kit runs.
class CameraSessionHelper {
  CameraSessionHelper._();

  static const Duration defaultPreviewDelay = Duration(milliseconds: 400);

  /// Kiosk: preview-only delay before ML stream (tablet-aware).
  static Duration get kioskPreviewDelay => CameraRuntime.kioskPreviewDelay;

  /// Enrollment: skip ML while AVFoundation + ML Kit settle on iOS.
  static const Duration mlKitSettleDelay = Duration(milliseconds: 900);

  /// Kiosk unlock: minimal settle — recognition starts almost immediately.
  static Duration get kioskMlSettleDelay => CameraRuntime.kioskMlSettleDelay;

  static List<CameraDescription>? _cachedCameras;
  static Future<List<CameraDescription>>? _camerasFuture;

  /// Primes the camera list during app bootstrap (non-blocking).
  static void warmUpCameraList() {
    _camerasFuture ??= availableCameras().then((list) {
      _cachedCameras = list;
      return list;
    });
  }

  static Future<List<CameraDescription>> _cameras() async {
    if (_cachedCameras != null) return _cachedCameras!;
    if (_camerasFuture != null) return _camerasFuture!;
    final list = await availableCameras();
    _cachedCameras = list;
    return list;
  }

  /// Platform enrollment settle (iOS keeps longer delay on phones).
  static Duration enrollmentMlSettleDelay() => CameraRuntime.enrollmentMlSettleDelay();

  /// Platform enrollment preview delay before starting the image stream.
  static Duration enrollmentPreviewDelay() => CameraRuntime.enrollmentPreviewDelay();

  static Future<CameraController?> openFrontCamera({
    ResolutionPreset? preset,
  }) async {
    try {
      final cameras = await _cameras();
      if (cameras.isEmpty) return null;

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        preset ?? CameraRuntime.frontCameraPreset,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      return controller;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('CameraSessionHelper.openFrontCamera failed: $e\n$st');
      }
      return null;
    }
  }

  /// Shows [CameraPreview] first, then starts the frame stream (avoids frozen UI).
  static Future<void> startImageStreamAfterPreview({
    required CameraController controller,
    required void Function(CameraImage image) onFrame,
    Duration previewDelay = defaultPreviewDelay,
  }) async {
    if (previewDelay > Duration.zero) {
      await Future<void>.delayed(previewDelay);
    }
    if (!controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;
    try {
      await controller.startImageStream(onFrame);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('CameraSessionHelper.startImageStream failed: $e\n$st');
      }
    }
  }

  static Future<void> stopImageStream(CameraController? controller) async {
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (!controller.value.isStreamingImages) return;
    try {
      await controller.stopImageStream();
    } catch (_) {}
  }

  /// Stops the live stream briefly so [takePicture] does not freeze on iOS/iPad.
  static Future<XFile?> takeStillPicture(CameraController controller) async {
    if (!controller.value.isInitialized) return null;
    final wasStreaming = controller.value.isStreamingImages;
    try {
      if (wasStreaming) {
        await stopImageStream(controller);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return await controller.takePicture();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('CameraSessionHelper.takeStillPicture failed: $e\n$st');
      }
      return null;
    }
  }

  static Future<void> disposeCamera(CameraController? controller) async {
    if (controller == null) return;
    await stopImageStream(controller);
    try {
      await controller.dispose();
    } catch (_) {}
  }
}
