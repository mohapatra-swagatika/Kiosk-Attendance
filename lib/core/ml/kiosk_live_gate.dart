import 'dart:math' as math;

import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Fast kiosk anti-spoof — blink + brief stability, no head-turn prompts.
///
/// Passes once per attendance attempt, then stays open for instant matching.
class KioskLiveGate {
  bool _passed = false;
  int _faceFrames = 0;
  int _stableFrames = 0;
  bool _sawBlink = false;
  bool _sawEyesClosed = false;
  double? _lastCx;
  double? _lastCy;
  double? _smoothCx;
  double? _smoothCy;

  static const int _minStableFrames = 1;
  static const double _centerEmaAlpha = 0.38;
  static const int _minFaceFrames = 1;
  static const double _maxJitter = 0.06;
  /// Open live gate sooner when user does not blink (faster first match / unknown).
  static const int _blinkFallbackFrames = 3;

  bool get isOpen => _passed;

  void reset() {
    _passed = false;
    _faceFrames = 0;
    _stableFrames = 0;
    _sawBlink = false;
    _sawEyesClosed = false;
    _lastCx = null;
    _lastCy = null;
    _smoothCx = null;
    _smoothCy = null;
  }

  /// Returns null when recognition may proceed; otherwise a one-time hint.
  String? feed(FaceFrameAnalysis analysis) {
    if (_passed) return null;

    if (!analysis.hasSingleFace || analysis.face == null) {
      _stableFrames = 0;
      return null;
    }

    _faceFrames++;
    final face = analysis.face!;
    final w = analysis.imageWidth;
    final h = analysis.imageHeight;
    if (w <= 0 || h <= 0) return null;

    final box = face.boundingBox;
    final cx = box.center.dx / w;
    final cy = box.center.dy / h;
    if (_smoothCx == null || _smoothCy == null) {
      _smoothCx = cx;
      _smoothCy = cy;
    } else {
      _smoothCx = _smoothCx! + (cx - _smoothCx!) * _centerEmaAlpha;
      _smoothCy = _smoothCy! + (cy - _smoothCy!) * _centerEmaAlpha;
    }
    if (_lastCx != null && _lastCy != null) {
      final jitter =
          (_smoothCx! - _lastCx!).abs() + (_smoothCy! - _lastCy!).abs();
      if (jitter < _maxJitter) {
        _stableFrames++;
      } else {
        _stableFrames = math.max(0, _stableFrames - 1);
      }
    }
    _lastCx = _smoothCx;
    _lastCy = _smoothCy;

    _trackBlink(face);

    if (_faceFrames >= _minFaceFrames &&
        _stableFrames >= _minStableFrames &&
        (_sawBlink || _faceFrames >= _blinkFallbackFrames)) {
      _passed = true;
      return null;
    }

    return null;
  }

  void _trackBlink(Face face) {
    final le = face.leftEyeOpenProbability;
    final re = face.rightEyeOpenProbability;
    if (le == null || re == null) return;
    final avg = (le + re) / 2;
    if (!_sawEyesClosed && avg < 0.38) _sawEyesClosed = true;
    if (_sawEyesClosed && avg > 0.55) _sawBlink = true;
  }
}
