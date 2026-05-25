import 'dart:io';

import 'package:camera/camera.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:attendance_kiosk_app/core/camera/camera_session_helper.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/storage/attendance_photo_store.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employee_portal/presentation/providers/employee_portal_providers.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

/// Front-camera selfie capture for employee check-in / check-out (offline).
class EmployeeAttendanceCapturePage extends ConsumerStatefulWidget {
  const EmployeeAttendanceCapturePage({
    super.key,
    required this.employee,
    required this.isCheckOut,
  });

  final Employee employee;
  final bool isCheckOut;

  @override
  ConsumerState<EmployeeAttendanceCapturePage> createState() =>
      _EmployeeAttendanceCapturePageState();
}

class _EmployeeAttendanceCapturePageState
    extends ConsumerState<EmployeeAttendanceCapturePage> {
  CameraController? _camera;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  @override
  void dispose() {
    final c = _camera;
    _camera = null;
    unawaited(CameraSessionHelper.disposeCamera(c));
    super.dispose();
  }

  Future<void> _openCamera() async {
    final perm = await Permission.camera.request();
    if (!perm.isGranted) {
      if (mounted) {
        setState(() => _error = EmployeePortalStrings.cameraPermissionRequired);
      }
      return;
    }

    final controller = await CameraSessionHelper.openFrontCamera(
      preset: ResolutionPreset.medium,
    );
    if (!mounted) return;
    if (controller == null) {
      setState(() => _error = KioskStrings.cameraPermissionRequired);
      return;
    }
    setState(() => _camera = controller);
  }

  Future<void> _captureAndSubmit() async {
    final camera = _camera;
    if (camera == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final xFile = await camera.takePicture();
      final storedPath = await const AttendancePhotoStore().saveFromFile(
        source: File(xFile.path),
        employeeId: widget.employee.id,
        isCheckOut: widget.isCheckOut,
      );

      final repo = ref.read(attendanceRepositoryProvider);
      final result = widget.isCheckOut
          ? await repo.checkOut(widget.employee, photoPath: storedPath)
          : await repo.checkIn(widget.employee, photoPath: storedPath);

      if (!mounted) return;

      result.fold(
        (f) => setState(() {
          _busy = false;
          _error = f.message;
        }),
        (_) {
          ref.invalidate(employeeActiveCheckInProvider);
          ref.invalidate(attendanceLogsProvider);
          Navigator.of(context).pop(true);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = EmployeePortalStrings.captureFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCheckOut
        ? EmployeePortalStrings.captureTitleCheckOut
        : EmployeePortalStrings.captureTitleCheckIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : _camera == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white54),
                              SizedBox(height: 16),
                              Text(
                                EmployeePortalStrings.captureLoading,
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_camera!),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                color: Colors.black54,
                                child: Text(
                                  EmployeePortalStrings.captureHint,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed:
                    _camera == null || _busy || _error != null ? null : _captureAndSubmit,
                icon: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(
                  _busy
                      ? EmployeePortalStrings.captureSaving
                      : EmployeePortalStrings.captureButton,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
