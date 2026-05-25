import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:attendance_kiosk_app/core/camera/camera_frame_pipeline.dart';
import 'package:attendance_kiosk_app/core/camera/camera_scan_lifecycle.dart';
import 'package:attendance_kiosk_app/core/camera/kiosk_attendance_photo_capture.dart';
import 'package:attendance_kiosk_app/core/camera/camera_session_helper.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/face_id/presentation/widgets/face_id_scanner_overlay.dart';
import 'package:attendance_kiosk_app/features/kiosk/domain/kiosk_recognition_pipeline.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/kiosk_ui_presenter.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/providers/kiosk_face_providers.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/providers/kiosk_scan_session.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/employee_match_dialog.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/no_employee_dialog.dart';

/// Face-scan kiosk panel — recognition pipeline unchanged.
class KioskCameraPanel extends ConsumerStatefulWidget {
  const KioskCameraPanel({super.key});

  @override
  ConsumerState<KioskCameraPanel> createState() => _KioskCameraPanelState();
}

class _KioskCameraPanelState extends ConsumerState<KioskCameraPanel>
    with WidgetsBindingObserver, CameraScanLifecycle {
  CameraController? _camera;
  KioskRecognitionPipeline? _pipeline;
  final _ui = KioskUiPresenter();
  final _framePipeline = CameraFramePipeline();
  DateTime? _mlStreamStartedAt;
  DateTime _lastUiRebuild = DateTime.fromMillisecondsSinceEpoch(0);
  int _galleryCount = 0;
  final Map<String, Employee> _employeesById = {};

  @override
  CameraController? get lifecycleCamera => _camera;

  @override
  CameraFramePipeline get lifecycleFramePipeline => _framePipeline;

  @override
  void Function(CameraImage image)? get lifecycleOnFrame => _onCameraFrame;

  void _onCameraFrame(CameraImage image) {
    _framePipeline.submit(image: image, processor: _processFrame);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_bootstrap()));
  }

  @override
  void dispose() {
    _framePipeline.reset();
    final c = _camera;
    _camera = null;
    unawaited(CameraSessionHelper.disposeCamera(c));
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    _ui.setInitializing(FaceRegistrationStrings.preparingCamera);
    _scheduleUiRebuild();

    _pipeline = KioskRecognitionPipeline(
      analyzer: ref.read(kioskFaceAnalyzerProvider),
      faceRepository: ref.read(faceRepositoryProvider),
    );

    unawaited(_initCamera());

    final preloadEither = await ref.read(faceRepositoryProvider).preloadGallery();
    if (!mounted) return;

    preloadEither.fold(
      (f) {
        _ui.setInitializing(f.message);
        _scheduleUiRebuild();
      },
      (count) {
        _galleryCount = count;
        _ui.setReady(enrolledCount: count);
        _scheduleUiRebuild();
      },
    );

    final employees = await ref.read(employeesListProvider.future);
    _employeesById.addEntries(employees.map((e) => MapEntry(e.id, e)));
  }

  Future<void> _initCamera() async {
    final perm = await Permission.camera.request();
    if (!perm.isGranted) {
      if (mounted) {
        _ui.setInitializing(KioskStrings.cameraPermissionRequired);
        _scheduleUiRebuild();
      }
      return;
    }

    if (perm.isPermanentlyDenied) {
      if (mounted) {
        _ui.setInitializing(KioskStrings.cameraPermissionRequired);
        _scheduleUiRebuild();
      }
      return;
    }

    final controller = await CameraSessionHelper.openFrontCamera();
    if (!mounted) return;

    if (controller == null) {
      _ui.setInitializing('No camera available');
      _scheduleUiRebuild();
      return;
    }

    setState(() => _camera = controller);

    await CameraSessionHelper.startImageStreamAfterPreview(
      controller: controller,
      previewDelay: CameraSessionHelper.kioskPreviewDelay,
      onFrame: _onCameraFrame,
    );

    _mlStreamStartedAt = DateTime.now();
    if (_galleryCount > 0) {
      _ui.setReady(enrolledCount: _galleryCount);
      _scheduleUiRebuild();
    }
  }

  void _scheduleUiRebuild({bool force = false}) {
    if (!mounted) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastUiRebuild).inMilliseconds < 180) {
      return;
    }
    _lastUiRebuild = now;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    final pipeline = _pipeline;
    final camera = _camera;
    if (pipeline == null || camera == null) return;

    final scan = ref.read(kioskScanSessionProvider);
    if (scan.dialogOpen || scan.scanPaused) return;

    final started = _mlStreamStartedAt;
    if (started != null &&
        DateTime.now().difference(started) < CameraSessionHelper.kioskMlSettleDelay) {
      return;
    }

    // Empty gallery: no recognition work (preview-only).
    if (_galleryCount == 0) return;

    final session = ref.read(kioskScanSessionProvider.notifier);
    final tick = await pipeline.processFrame(
      image: image,
      description: camera.description,
      orientation: camera.value.deviceOrientation,
      session: session,
    );

    if (!mounted) return;
    if (ref.read(kioskScanSessionProvider).dialogOpen) return;

    switch (tick) {
      case KioskPipelineIdle():
        break;
      case KioskPipelineStatus():
        if (_ui.applyPipelineTick(tick)) _scheduleUiRebuild();
        break;
      case KioskPipelineMatch(:final employeeId, :final confidence):
        unawaited(HapticFeedback.mediumImpact());
        if (_ui.applyPipelineTick(tick, employeeName: _employeesById[employeeId]?.name)) {
          _scheduleUiRebuild(force: true);
        }
        unawaited(_openMatchDialog(employeeId, confidence));
      case KioskPipelineUnknown(:final reason):
        unawaited(HapticFeedback.heavyImpact());
        if (_ui.applyPipelineTick(tick)) _scheduleUiRebuild(force: true);
        unawaited(_showUnknown(reason));
    }
  }

  Future<void> _showUnknown(String reason) async {
    final session = ref.read(kioskScanSessionProvider.notifier);
    if (ref.read(kioskScanSessionProvider).dialogOpen) return;

    await pauseCameraScanning();
    session.onUnknownDialogOpening();
    if (!mounted) return;
    await showNoEmployeeDialog(context, reason: reason);
    session.onDialogClosed(matched: false);
    session.softResetAfterDialog();
    _pipeline?.softReset();
    if (mounted) {
      _ui.afterDialogClosed(enrolledCount: _galleryCount);
      await resumeCameraScanning();
      _scheduleUiRebuild(force: true);
    }
  }

  Future<void> _openMatchDialog(String employeeId, double confidence) async {
    final session = ref.read(kioskScanSessionProvider.notifier);
    if (ref.read(kioskScanSessionProvider).dialogOpen) return;

    var employee = _employeesById[employeeId];
    if (employee == null) {
      final list = ref.read(employeesListProvider).valueOrNull;
      if (list != null) {
        for (final e in list) {
          if (e.id == employeeId) {
            employee = e;
            _employeesById[employeeId] = e;
            break;
          }
        }
      }
    }
    if (employee == null) {
      unawaited(_showUnknown(KioskStrings.unknownFace));
      return;
    }
    final matchedEmployee = employee;

    session.onDialogOpening(employeeId);
    await pauseCameraScanning();
    if (!mounted) return;

    final activeEither =
        await ref.read(attendanceRepositoryProvider).getActiveCheckIn(matchedEmployee.id);
    final active = activeEither.fold((_) => null, (a) => a);
    final isCheckOut = active != null && active.isActiveCheckIn;

    if (!mounted) return;
    await showEmployeeMatchDialog(
      context: context,
      ref: ref,
      employee: matchedEmployee,
      activeLog: active,
      confidence: confidence,
      onCaptureAttendancePhoto: () => const KioskAttendancePhotoCapture().capture(
        controller: _camera,
        employeeId: matchedEmployee.id,
        isCheckOut: isCheckOut,
      ),
    );

    session.onDialogClosed(matched: true);
    session.softResetAfterDialog();
    _pipeline?.softReset();
    if (mounted) {
      _ui.afterDialogClosed(enrolledCount: _galleryCount);
      await resumeCameraScanning();
      _scheduleUiRebuild(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _ui.snapshot;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_camera != null)
            CameraPreview(_camera!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white54)),
          FaceIdRecognitionOverlay(
            status: snap.message,
            subtitle: snap.subtitle,
            isVerified: snap.isVerified,
            isScanning: snap.isScanning && _galleryCount > 0,
          ),
        ],
      ),
    );
  }
}
