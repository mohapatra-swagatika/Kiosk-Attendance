import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/features/kiosk/domain/kiosk_recognition_pipeline.dart';

/// Kiosk on-screen copy — show each instruction once, avoid flicker/repeat.
enum KioskUiPhase {
  initializing,
  ready,
  recognizing,
  verified,
  unknown,
}

class KioskUiSnapshot {
  const KioskUiSnapshot({
    required this.phase,
    required this.message,
    this.subtitle,
    this.isVerified = false,
    this.isScanning = false,
  });

  final KioskUiPhase phase;
  final String message;
  final String? subtitle;
  final bool isVerified;
  final bool isScanning;
}

/// Maps pipeline ticks to stable UI (production kiosk UX).
class KioskUiPresenter {
  KioskUiPhase _phase = KioskUiPhase.initializing;
  String _message = FaceRegistrationStrings.preparingCamera;
  String? _subtitle;
  bool _verified = false;

  KioskUiSnapshot get snapshot => KioskUiSnapshot(
        phase: _phase,
        message: _message,
        subtitle: _subtitle,
        isVerified: _verified,
        isScanning: _phase == KioskUiPhase.ready ||
            _phase == KioskUiPhase.recognizing,
      );

  void setInitializing(String message) {
    _phase = KioskUiPhase.initializing;
    _message = message;
    _subtitle = null;
    _verified = false;
  }

  void setReady({String? subtitle, int enrolledCount = 0}) {
    _phase = KioskUiPhase.ready;
    _verified = false;
    _message = enrolledCount == 0
        ? 'No enrolled faces — register employees first'
        : FaceIdStrings.kioskReady;
    _subtitle = subtitle;
  }

  /// Returns true when the widget should rebuild.
  bool applyPipelineTick(KioskPipelineTick tick, {String? employeeName}) {
    switch (tick) {
      case KioskPipelineIdle():
        return false;
      case KioskPipelineStatus(:final message):
        if (_phase == KioskUiPhase.verified) return false;
        if (_phase == KioskUiPhase.ready && message == FaceIdStrings.kioskAlign) {
          return false;
        }
        if (_message == message) return false;
        _phase = KioskUiPhase.recognizing;
        _message = message;
        return true;
      case KioskPipelineMatch():
        _phase = KioskUiPhase.verified;
        _verified = true;
        _message = FaceIdStrings.verified;
        _subtitle = employeeName;
        return true;
      case KioskPipelineUnknown():
        _phase = KioskUiPhase.unknown;
        _verified = false;
        _message = KioskStrings.noEmployeeFoundTitle;
        _subtitle = null;
        return true;
    }
  }

  void afterDialogClosed({int enrolledCount = 0}) {
    _phase = KioskUiPhase.ready;
    _verified = false;
    _message = enrolledCount == 0
        ? 'No enrolled faces — register employees first'
        : FaceIdStrings.kioskReady;
    _subtitle = null;
  }
}
