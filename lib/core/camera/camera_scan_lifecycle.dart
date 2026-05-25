import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_kiosk_app/core/camera/camera_frame_pipeline.dart';
import 'package:attendance_kiosk_app/core/camera/camera_session_helper.dart';

/// Pauses the image stream when the app backgrounds or overlays block scanning.
mixin CameraScanLifecycle<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  CameraController? get lifecycleCamera;
  CameraFramePipeline get lifecycleFramePipeline;
  void Function(CameraImage image)? get lifecycleOnFrame;

  bool _lifecyclePaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_lifecyclePaused) {
          _lifecyclePaused = false;
          unawaited(resumeCameraScanning());
        }
      // Do not pause on [inactive] — iOS/iPad fire it during camera start,
      // route transitions, and overlays; that was stopping enrollment ML.
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (!_lifecyclePaused) {
          _lifecyclePaused = true;
          unawaited(pauseCameraScanning());
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Stop ML work and the native stream (dialogs, saving, background).
  Future<void> pauseCameraScanning() async {
    lifecycleFramePipeline.pause();
    final c = lifecycleCamera;
    if (c != null) {
      await CameraSessionHelper.stopImageStream(c);
    }
  }

  /// Restart stream after [pauseCameraScanning].
  Future<void> resumeCameraScanning() async {
    if (!mounted) return;
    lifecycleFramePipeline.resume();
    final c = lifecycleCamera;
    final onFrame = lifecycleOnFrame;
    if (c == null || onFrame == null) return;
    await CameraSessionHelper.startImageStreamAfterPreview(
      controller: c,
      previewDelay: Duration.zero,
      onFrame: onFrame,
    );
  }
}
