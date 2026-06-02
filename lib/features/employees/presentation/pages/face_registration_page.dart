import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:attendance_kiosk_app/core/camera/camera_frame_pipeline.dart';
import 'package:attendance_kiosk_app/core/camera/camera_runtime.dart';
import 'package:attendance_kiosk_app/core/camera/camera_scan_lifecycle.dart';
import 'package:attendance_kiosk_app/core/camera/camera_session_helper.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/ml/camera_frame_clone.dart';
import 'package:attendance_kiosk_app/core/ml/face_id_live_metrics.dart';
import 'package:attendance_kiosk_app/core/ml/android_nv21_align.dart';
import 'package:attendance_kiosk_app/core/ml/face_registration_session.dart';
import 'package:attendance_kiosk_app/core/ml/face_recognition_trace.dart';
import 'package:attendance_kiosk_app/core/ml/face_track_smoother.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_analyzer.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/face_data_sync_providers.dart';
import 'package:attendance_kiosk_app/app/bootstrap.dart' show appFaceEmbedder;
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/face_id/presentation/widgets/face_id_scanner_overlay.dart';

/// Face ID enrollment — continuous tracking, pose-driven ring, same-frame capture.
class FaceRegistrationPage extends ConsumerStatefulWidget {
  const FaceRegistrationPage({super.key, required this.employeeId});

  final String employeeId;

  @override
  ConsumerState<FaceRegistrationPage> createState() =>
      _FaceRegistrationPageState();
}

class _FaceRegistrationPageState extends ConsumerState<FaceRegistrationPage>
    with TickerProviderStateMixin, WidgetsBindingObserver, CameraScanLifecycle {
  CameraController? _camera;
  final _analyzer = MlKitFaceAnalyzer.enrollment();
  final _session = FaceRegistrationSession(guided: true);

  String _status = FaceRegistrationStrings.preparingCamera;
  String? _detail;
  bool _disposed = false;
  final _framePipeline = CameraFramePipeline();
  bool _saving = false;
  bool _finalizeStarted = false;
  bool _blocked = false;
  String? _blockedTitle;
  bool _enrollmentComplete = false;

  FaceIdEnrollPhase _lastPhase = FaceIdEnrollPhase.positioning;
  FaceIdGuidedStep _lastGuidedStep = FaceIdGuidedStep.straight;
  DateTime _lastMlAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _mlStreamStartedAt;
  bool _mlKitPrimed = false;
  bool _mlPrimeInProgress = false;
  bool _mlWarmupComplete = false;
  String? _employeeDisplayName;
  String? _employeeDisplayCode;
  Ticker? _uiTicker;
  double _lastRingShown = 0;
  Offset? _smoothedFaceDot;
  final _faceTrackSmoother = FaceTrackSmoother();

  Duration get _mlInterval => CameraRuntime.enrollmentDetectInterval;

  @override
  CameraController? get lifecycleCamera => _camera;

  @override
  CameraFramePipeline get lifecycleFramePipeline => _framePipeline;

  @override
  void Function(CameraImage image)? get lifecycleOnFrame => _onEnrollmentFrame;

  void _onEnrollmentFrame(CameraImage image) {
    _framePipeline.submit(image: image, processor: _processFrame);
  }

  /// Face-position dot for the ring overlay (mirrored on Android for preview).
  Offset? _faceDotForOverlay(FaceIdLiveMetrics metrics) {
    final raw = metrics.faceOffsetNormalized;
    if (raw == null || !metrics.hasFace) {
      _smoothedFaceDot = null;
      return null;
    }
    if (metrics.centerScore >= 0.55) {
      _smoothedFaceDot = null;
      return null;
    }
    _smoothedFaceDot = _smoothedFaceDot == null
        ? raw
        : Offset.lerp(_smoothedFaceDot!, raw, 0.22)!;
    return _smoothedFaceDot;
  }

  @override
  void initState() {
    super.initState();
    AndroidNv21AlignCalibrator.resetEnrollment();
    _session.resetForNewEnrollment();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _uiTicker = createTicker(_onUiTick)..start();
    _resolveEmployeeDisplayName();
    unawaited(_init());
  }

  void _resolveEmployeeDisplayName() {
    final employees = ref.read(employeesListProvider).valueOrNull;
    if (employees != null) {
      for (final e in employees) {
        if (e.id == widget.employeeId) {
          _employeeDisplayName = e.name.trim().isNotEmpty
              ? e.name.trim()
              : null;
          _employeeDisplayCode = e.employeeCode?.isNotEmpty == true
              ? e.employeeCode!
              : null;
          return;
        }
      }
    }
    unawaited(
      ref.read(employeeByIdProvider(widget.employeeId).future).then((employee) {
        if (!mounted || employee == null) return;
        final name = employee.name.trim();
        if (name.isNotEmpty) {
          setState(() => _employeeDisplayName = name);
        }
        final code = employee.employeeCode?.trim();
        if (code != null && code.isNotEmpty) {
          setState(() => _employeeDisplayCode = code);
        }
      }),
    );
  }

  String get _snackbarEmployeeLabel =>
      _employeeDisplayName ?? widget.employeeId;

  String get _alreadyEnrolledLabel => _employeeDisplayCode ?? widget.employeeId;

  /// Keeps the ring filling smoothly between ML Kit frames (~60fps).
  void _onUiTick(Duration _) {
    if (!mounted || _blocked || _disposed) return;
    _session.tickAnimation();
    final ring = _session.faceIdRingProgress;
    final ringMoved = (ring - _lastRingShown).abs() > 0.002;
    if (ringMoved) _lastRingShown = ring;
    // Android: refresh guidance every tick for smoother phase/ring feedback.
    if (!ringMoved && !_session.isLocked && !Platform.isAndroid) return;
    setState(() {
      _status = _session.statusMessage ?? _session.primaryGuidance;
      _detail = _session.detailMessage;
    });
  }

  Future<void> _init() async {
    final faceRepo = ref.read(faceRepositoryProvider);
    final permFuture = Permission.camera.request();
    final hasFaceFuture = faceRepo.hasRegisteredFace(widget.employeeId);

    final perm = await permFuture;
    if (!perm.isGranted) {
      if (!mounted) return;
      setState(() {
        _blocked = true;
        _blockedTitle = FaceRegistrationStrings.cameraRequiredTitle;
        _status = FaceRegistrationStrings.cameraRequiredBody;
      });
      return;
    }

    final hasFace = await hasFaceFuture;
    hasFace.fold((_) {}, (exists) {
      if (exists && mounted) {
        setState(() {
          _blocked = true;
          _blockedTitle = FaceRegistrationStrings.alreadyEnrolledTitle;
          _status = FaceRegistrationStrings.alreadyEnrolledBody(
            _alreadyEnrolledLabel,
          );
          _detail = FaceRegistrationStrings.alreadyEnrolledHint;
        });
      }
    });
    if (_blocked) return;

    try {
      if (mounted) {
        setState(() {
          _status = FaceRegistrationStrings.preparingCamera;
          _detail = 'Opening front camera…';
        });
      }

      final controller = await CameraSessionHelper.openFrontCamera();
      if (!mounted) return;

      if (controller == null) {
        setState(() {
          _blocked = true;
          _blockedTitle = FaceRegistrationStrings.cameraRequiredTitle;
          _status = 'No camera available';
        });
        return;
      }

      setState(() {
        _camera = controller;
        _status = FaceRegistrationStrings.preparingCamera;
        _detail = 'Starting preview…';
      });

      // Ensure the preview has at least one frame painted before we start
      // any ML work (first ML Kit inference can be slow).
      await SchedulerBinding.instance.endOfFrame;

      if (!mounted) return;

      // Lazily load the TFLite face embedder here (NOT during app startup).
      // On some iOS devices the interpreter creation can block for several seconds,
      // so we do it inside the enrollment flow with visible progress.
      if (!appFaceEmbedder.isReady) {
        if (mounted) {
          setState(() {
            _status = FaceRegistrationStrings.preparingFaceScanner;
            _detail = 'Loading face recognition model…';
          });
        }
        await appFaceEmbedder.initialize();
      }

      await CameraSessionHelper.startImageStreamAfterPreview(
        controller: controller,
        previewDelay: CameraSessionHelper.enrollmentPreviewDelay(),
        onFrame: _onEnrollmentFrame,
      );

      _mlStreamStartedAt = DateTime.now();
      if (mounted) {
        setState(() {
          _status = FaceRegistrationStrings.faceIdPositionFace;
          _detail = FaceRegistrationStrings.preparingFaceScanner;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _blocked = true;
        _blockedTitle = FaceRegistrationStrings.cameraRequiredTitle;
        _status = 'Could not start camera: $e';
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_disposed || _blocked || _camera == null) return;

    final started = _mlStreamStartedAt;
    if (started != null &&
        DateTime.now().difference(started) <
            CameraSessionHelper.enrollmentMlSettleDelay(
              mlKitPrimed: _mlKitPrimed,
            )) {
      return;
    }

    if (_session.isLocked) {
      if (!_finalizeStarted) unawaited(_finalizeRegistration());
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastMlAt) < _mlInterval) return;
    _lastMlAt = now;

    final clone = CameraFrameClone.fromCameraImage(
      image: image,
      description: _camera!.description,
      orientation: _camera!.value.deviceOrientation,
    );
    if (clone == null) return;

    try {
      // First-time ML Kit inference can take ~20–30s on some iOS devices.
      // Run a one-time warm-up pass while keeping the preview visible.
      if (!_mlWarmupComplete) {
        if (_mlPrimeInProgress) return;
        _mlPrimeInProgress = true;
        try {
          if (mounted) {
            setState(() {
              _status = FaceRegistrationStrings.preparingFaceScanner;
              _detail =
                  'Warming up face scanner (first time only)… Please wait.';
            });
          }
          final warm = await _analyzer.analyzeClone(clone);
          _mlKitPrimed = warm.faceCount >= 0; // any result implies model loaded
          _mlWarmupComplete = true;
          if (mounted) {
            setState(() {
              _status = FaceRegistrationStrings.faceIdPositionFace;
              _detail = null;
            });
          }
        } finally {
          _mlPrimeInProgress = false;
        }
        return;
      }

      final analysis = await _analyzer.analyzeClone(clone);
      if (_disposed || !mounted) return;

      double? smoothCx;
      double? smoothCy;
      if (Platform.isAndroid &&
          analysis.hasSingleFace &&
          analysis.face != null) {
        final c = analysis.face!.boundingBox.center;
        final s = _faceTrackSmoother.smooth(c.dx, c.dy);
        smoothCx = s.dx;
        smoothCy = s.dy;
      } else if (!analysis.hasSingleFace) {
        _faceTrackSmoother.reset();
      }

      final needsCapture = _session.processFrame(
        analysis,
        smoothedCenterX: smoothCx,
        smoothedCenterY: smoothCy,
      );
      _emitPhaseFeedback();
      if (Platform.isAndroid &&
          _session.guidedStep != _lastGuidedStep &&
          _session.phase == FaceIdEnrollPhase.scanning) {
        _lastGuidedStep = _session.guidedStep;
        unawaited(HapticFeedback.selectionClick());
      }

      if (mounted) {
        setState(() {
          _status = _session.statusMessage ?? _session.primaryGuidance;
          _detail = _session.detailMessage;
        });
      }

      if (needsCapture &&
          analysis.hasSingleFace &&
          analysis.face != null &&
          !_session.isLocked) {
        unawaited(_captureFromClone(clone, analysis.face!));
      }

      if (_session.isLocked && !_finalizeStarted) {
        if (!_enrollmentComplete) {
          unawaited(HapticFeedback.heavyImpact());
          if (mounted) setState(() => _enrollmentComplete = true);
        }
        unawaited(_finalizeRegistration());
      }
    } catch (_) {
      // Transient ML errors — next frame recovers.
    }
  }

  void _emitPhaseFeedback() {
    final phase = _session.phase;
    if (phase != _lastPhase) {
      _lastPhase = phase;
      switch (phase) {
        case FaceIdEnrollPhase.scanning:
          unawaited(HapticFeedback.lightImpact());
        case FaceIdEnrollPhase.finished:
          unawaited(HapticFeedback.heavyImpact());
        default:
          break;
      }
    }
  }

  Future<void> _captureFromClone(CameraFrameClone clone, Face face) async {
    _session.markCaptureStarted();
    try {
      final capture = await _analyzer
          .captureForEnrollment(
            clone: clone,
            face: face,
            priorEmbeddings: _session.captureEmbeddings,
          )
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => const NeuralCaptureResult.failure(
              'Hold still — capture timed out',
            ),
          );

      final ok = capture.ok && capture.embedding != null;
      _session.markCaptureFinished(success: ok, embedding: capture.embedding);
      if (ok && !Platform.isAndroid) {
        unawaited(HapticFeedback.selectionClick());
      } else if (mounted && capture.message != null && !Platform.isAndroid) {
        setState(() {
          _detail = capture.message;
        });
      }
    } catch (_) {
      _session.markCaptureFinished(success: false, embedding: null);
    }
  }

  Future<void> _finalizeRegistration() async {
    if (_saving || _finalizeStarted) return;
    _finalizeStarted = true;
    await pauseCameraScanning();

    if (mounted) {
      setState(() {
        _saving = true;
        _status = FaceRegistrationStrings.faceIdComplete;
        _detail = FaceRegistrationStrings.saving;
      });
    }

    final profile = _session.buildProfilePayload();
    if (profile == null) {
      if (mounted) {
        setState(() {
          _saving = false;
          _finalizeStarted = false;
          _enrollmentComplete = false;
          _status = FaceRegistrationStrings.saveFailed;
          _detail = null;
        });
        await resumeCameraScanning();
      }
      return;
    }

    final sampleCount = (profile['samples'] as num?)?.toInt() ?? 0;
    final yawSpread = (profile['yawSpread'] as num?)?.toDouble() ?? 0;
    FaceRecognitionTrace.registrationCompleted(
      employeeId: widget.employeeId,
      sampleCount: sampleCount,
      yawSpread: yawSpread,
    );

    final result = await ref
        .read(faceRepositoryProvider)
        .registerFaceProfile(employeeId: widget.employeeId, profile: profile);

    if (!mounted) return;
    result.fold(
      (f) async {
        setState(() {
          _saving = false;
          _finalizeStarted = false;
          _enrollmentComplete = false;
          _status = f.message;
          _detail = FaceRegistrationStrings.saveFailedHint;
        });
        await resumeCameraScanning();
        if (f is ValidationFailure && f.debugDetails != null && mounted) {
          unawaited(_showDebugDialog(f.message, f.debugDetails!));
        }
      },
      (_) {
        ref.invalidate(employeesListProvider);
        ref.invalidate(employeeHasFaceEmbeddingProvider(widget.employeeId));
        ref.invalidate(faceDataSyncPendingCountProvider);
        ref.invalidate(offlineSyncPendingCountProvider);
        // Kiosk panel may have cached enrolledCount=0 from before this enroll.
        ref.read(faceRepositoryProvider).invalidateGalleryCache();
        unawaited(ref.read(faceRepositoryProvider).preloadGallery());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              FaceRegistrationStrings.savedSnackbar(_snackbarEmployeeLabel),
            ),
          ),
        );
        context.pop(true);
      },
    );
  }

  Future<void> _showDebugDialog(String title, String details) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(FaceRegistrationStrings.debugDialogTitle),
        content: SingleChildScrollView(
          child: SelectableText(
            '$title\n\n$details',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.ok),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _framePipeline.reset();
    _uiTicker?.dispose();
    _uiTicker = null;
    unawaited(_teardownCamera());
    super.dispose();
  }

  Future<void> _teardownCamera() async {
    final c = _camera;
    _camera = null;
    await CameraSessionHelper.disposeCamera(c);
    try {
      await _analyzer.dispose();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesListProvider).valueOrNull;
    Employee? employee;
    if (employees != null) {
      for (final e in employees) {
        if (e.id == widget.employeeId) {
          employee = e;
          break;
        }
      }
    }

    final metrics = _session.liveMetrics;
    final ringProgress = _blocked ? 0.0 : _session.faceIdRingProgress;
    final subtitle = employee != null
        ? 'Enroll ${employee.name}'
        : FaceRegistrationStrings.faceIdSetupSubtitle;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_blocked)
            FaceIdScannerOverlay(
              cameraController: _camera,
              cameraLoading: _camera == null,
              ringProgress: _enrollmentComplete ? 1.0 : ringProgress,
              headline: FaceRegistrationStrings.faceIdTitle,
              subtitle: subtitle,
              guidance: _status,
              detail: _detail,
              isCapturing: _session.phase == FaceIdEnrollPhase.scanning,
              isComplete: _enrollmentComplete,
              faceDotOffset: _faceDotForOverlay(metrics),
              // Android front camera preview is mirrored; keep pose validation as-is,
              // but flip the on-screen arrow so the *user action* matches what they see.
              arrowDirection: switch (_session.guidedStep) {
                FaceIdGuidedStep.left => Platform.isAndroid
                    ? FaceIdArrowDirection.right
                    : FaceIdArrowDirection.left,
                FaceIdGuidedStep.right => Platform.isAndroid
                    ? FaceIdArrowDirection.left
                    : FaceIdArrowDirection.right,
                FaceIdGuidedStep.up => Platform.isAndroid
                    ? FaceIdArrowDirection.down
                    : FaceIdArrowDirection.up,
                FaceIdGuidedStep.down => Platform.isAndroid
                    ? FaceIdArrowDirection.up
                    : FaceIdArrowDirection.down,
                _ => null,
              },
              highlightDirection:
                  Platform.isAndroid && _session.guidedPoseInTarget,
            )
          else
            FaceIdScannerOverlay(
              ringProgress: 0,
              headline: _blockedTitle ?? FaceRegistrationStrings.unavailable,
              guidance: _status,
              detail: _detail,
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 8,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                shape: const CircleBorder(),
              ),
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          if (_saving) const _SavingScrim(),
        ],
      ),
    );
  }
}

class _SavingScrim extends StatelessWidget {
  const _SavingScrim();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 14),
          Text(
            FaceRegistrationStrings.saving,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
