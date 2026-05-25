import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/core/widgets/dashboard/dashboard_section_header.dart';
import 'package:attendance_kiosk_app/core/widgets/glass_panel.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/widgets/active_attendance_strip.dart';
import 'package:attendance_kiosk_app/features/attendance/data/ml/camera_frame_converter.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';

/// Attendance workspace: live camera + ML Kit face count, queue cards, status.
class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  CameraController? _camera;
  bool _initializing = true;
  String? _error;
  int _faceCount = 0;
  bool _busyFrame = false;
  DateTime _lastDetect = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    unawaited(_setupCamera());
  }

  Future<void> _setupCamera() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      setState(() {
        _initializing = false;
        _error = AttendanceStrings.errAndroidIosOnly;
      });
      return;
    }

    final perm = await Permission.camera.request();
    if (!perm.isGranted) {
      setState(() {
        _initializing = false;
        _error = AttendanceStrings.errCameraPermission;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _error = AttendanceStrings.errNoCameras;
        });
        return;
      }

      CameraDescription? picked;
      for (final c in cameras) {
        if (c.lensDirection == CameraLensDirection.front) {
          picked = c;
          break;
        }
      }
      picked ??= cameras.first;

      final controller = CameraController(
        picked,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await ref.read(faceDetectionPortProvider).ensureInitialized();

      await controller.startImageStream((image) {
        unawaited(_onCameraFrame(image));
      });

      setState(() {
        _camera = controller;
        _initializing = false;
        _error = null;
      });
    } catch (e, st) {
      debugPrint('Camera init failed: $e\n$st');
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = AttendanceStrings.errCameraGeneric(e);
        });
      }
    }
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    final controller = _camera;
    if (controller == null || !controller.value.isStreamingImages) return;

    final now = DateTime.now();
    if (now.difference(_lastDetect).inMilliseconds < 240) return;
    if (_busyFrame) return;
    _busyFrame = true;
    _lastDetect = now;

    try {
      final frame = liveFrameFromCameraImage(
        image: image,
        description: controller.description,
        deviceOrientation: controller.value.deviceOrientation,
      );
      if (frame == null || !mounted) return;

      final faces = await ref.read(faceDetectionPortProvider).detectLive(frame);
      if (mounted) {
        setState(() => _faceCount = faces.length);
      }
    } catch (e, st) {
      debugPrint('Face frame error: $e\n$st');
    } finally {
      _busyFrame = false;
    }
  }

  Future<void> _retry() async {
    final c = _camera;
    _camera = null;
    if (c != null) {
      try {
        if (c.value.isStreamingImages) await c.stopImageStream();
      } catch (_) {}
      await c.dispose();
    }
    setState(() {
      _initializing = true;
      _error = null;
      _faceCount = 0;
    });
    await _setupCamera();
  }

  @override
  void dispose() {
    final c = _camera;
    _camera = null;
    if (c != null) {
      if (c.value.isStreamingImages) {
        unawaited(c.stopImageStream().catchError((_) {}));
      }
      unawaited(c.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_initializing) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AttendanceStrings.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const ActiveAttendanceStrip(
              cameraLive: false,
              faceCount: 0,
              initializing: true,
            ),
            const SizedBox(height: 32),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (_error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AttendanceStrings.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            ActiveAttendanceStrip(
              cameraLive: false,
              faceCount: 0,
              errorMessage: _error,
            ),
            const SizedBox(height: 24),
            Center(
              child: Icon(Icons.videocam_off, size: 48, color: scheme.error),
            ),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Center(child: FilledButton(onPressed: _retry, child: const Text(AppStrings.retry))),
          ],
        ),
      );
    }

    final controller = _camera;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return ResponsiveBuilder(
      builder: (context, bp, _) {
        final previewHeight = switch (bp) {
          AppBreakpointSize.compact => 280.0,
          AppBreakpointSize.medium => 360.0,
          AppBreakpointSize.expanded => 420.0,
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bp == AppBreakpointSize.compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AttendanceStrings.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _LivePill(active: controller.value.isStreamingImages),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            AttendanceStrings.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        _LivePill(active: controller.value.isStreamingImages),
                      ],
                    ),
              const SizedBox(height: 8),
              Text(
                AttendanceStrings.pipelineBlurb(_faceCount),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ActiveAttendanceStrip(
                cameraLive: controller.value.isStreamingImages,
                faceCount: _faceCount,
                initializing: false,
                errorMessage: null,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ColoredBox(
                  color: Colors.black,
                  child: SizedBox(
                    height: previewHeight,
                    width: double.infinity,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(controller),
                            Positioned(
                              left: 12,
                              top: 12,
                              child: GlassPanel(
                                borderRadius: 16,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.face, color: scheme.primary, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      AttendanceStrings.faceCount(_faceCount),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DashboardSectionHeader(
                title: AttendanceStrings.queueTitle,
                subtitle: AttendanceStrings.queueSubtitle,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    _EmployeeStackCard(
                      name: AttendanceStrings.queueNext,
                      status: AttendanceStrings.queueNextStatus,
                      color: Colors.teal,
                    ),
                    _EmployeeStackCard(
                      name: AttendanceStrings.queueVerifying,
                      status: AttendanceStrings.queueVerifyingStatus,
                      color: Colors.indigo,
                    ),
                    _EmployeeStackCard(
                      name: AttendanceStrings.queueCompleted,
                      status: AttendanceStrings.queueCompletedStatus,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(active ? AttendanceStrings.pillLive : AttendanceStrings.pillPaused,
              style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _EmployeeStackCard extends StatelessWidget {
  const _EmployeeStackCard({
    required this.name,
    required this.status,
    required this.color,
  });

  final String name;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 200,
        child: GlassPanel(
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(Icons.person, color: color)),
                  const Spacer(),
                  Icon(Icons.bolt, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(status, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
