import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';

/// Passive anti-spoof gate (blink, head motion, stability, distance).
///
/// **Registration only** — kiosk attendance uses instant Face ID–style unlock without
/// left/right prompts. This class is kept for optional future enrollment hardening.
class FaceLivenessValidator {
  FaceLivenessValidator();

  static const int _minFrames = 4;
  static const int _yawHistoryMax = 20;
  static const double _minYawSwing = 4.5;
  static const double _maxCenterJitter = 0.035;
  static const double _minVisibility = 0.12;
  static const double _maxVisibility = 0.55;
  static const double _blinkClosedThreshold = 0.35;
  static const double _blinkOpenThreshold = 0.55;

  final List<double> _yawHistory = [];
  final List<double> _centerXHistory = [];
  final List<double> _centerYHistory = [];

  int _frameCount = 0;
  bool _sawBlink = false;
  bool _sawEyesClosed = false;

  FaceLivenessState _state = FaceLivenessState.collecting;
  String? _hint;

  FaceLivenessState get state => _state;
  String? get hint => _hint;
  bool get isReady => _state == FaceLivenessState.passed;

  /// Resets the session (e.g. after dialog close or prolonged no-face).
  void reset() {
    _yawHistory.clear();
    _centerXHistory.clear();
    _centerYHistory.clear();
    _frameCount = 0;
    _sawBlink = false;
    _sawEyesClosed = false;
    _state = FaceLivenessState.collecting;
    _hint = null;
  }

  /// Feed each tracked face frame. Returns whether recognition may proceed.
  FaceLivenessUpdate feed(FaceFrameAnalysis analysis) {
    if (!analysis.hasSingleFace || analysis.face == null) {
      if (_frameCount > 0 && _frameCount < _minFrames) {
        _hint = 'Align your face in the circle';
      }
      return FaceLivenessUpdate(
        state: _state,
        hint: _hint,
        canRecognize: false,
      );
    }

    final face = analysis.face!;
    final w = analysis.imageWidth;
    final h = analysis.imageHeight;
    if (w <= 0 || h <= 0) {
      return FaceLivenessUpdate(state: _state, hint: _hint, canRecognize: false);
    }

    _frameCount++;
    _trackPose(face, w, h);
    _trackBlink(face);

    final visibility =
        (face.boundingBox.width * face.boundingBox.height) / (w * h);

    if (visibility < _minVisibility) {
      _hint = 'Move a little closer';
      _state = FaceLivenessState.collecting;
      return FaceLivenessUpdate(state: _state, hint: _hint, canRecognize: false);
    }
    if (visibility > _maxVisibility) {
      _hint = 'Move back slightly';
      _state = FaceLivenessState.collecting;
      return FaceLivenessUpdate(state: _state, hint: _hint, canRecognize: false);
    }

    if (_frameCount < _minFrames) {
      _hint = 'Hold still — scanning face';
      return FaceLivenessUpdate(state: _state, hint: _hint, canRecognize: false);
    }

    final yawSwing = _yawSwing();
    final jitter = _centerJitter(w, h);

    if (yawSwing < _minYawSwing) {
      _hint = 'Slowly turn your head left and right';
      _state = FaceLivenessState.collecting;
      return FaceLivenessUpdate(state: _state, hint: _hint, canRecognize: false);
    }

    if (jitter > _maxCenterJitter) {
      _hint = 'Hold still — face is moving too much';
      _state = FaceLivenessState.collecting;
      return FaceLivenessUpdate(state: _state, hint: _hint, canRecognize: false);
    }

    if (!_sawBlink) {
      _hint = _sawEyesClosed ? 'Open your eyes' : 'Blink once to verify you are live';
      _state = FaceLivenessState.collecting;
      return FaceLivenessUpdate(state: _state, hint: _hint, canRecognize: false);
    }

    _state = FaceLivenessState.passed;
    _hint = null;
    return FaceLivenessUpdate(
      state: _state,
      hint: null,
      canRecognize: true,
    );
  }

  void _trackPose(Face face, int w, int h) {
    final yaw = face.headEulerAngleY ?? 0;
    _yawHistory.add(yaw);
    while (_yawHistory.length > _yawHistoryMax) {
      _yawHistory.removeAt(0);
    }

    final box = face.boundingBox;
    _centerXHistory.add(box.center.dx / w);
    _centerYHistory.add(box.center.dy / h);
    while (_centerXHistory.length > _yawHistoryMax) {
      _centerXHistory.removeAt(0);
      _centerYHistory.removeAt(0);
    }
  }

  void _trackBlink(Face face) {
    final le = face.leftEyeOpenProbability;
    final re = face.rightEyeOpenProbability;
    if (le == null || re == null) return;
    final avg = (le + re) / 2;
    if (!_sawEyesClosed && avg < _blinkClosedThreshold) {
      _sawEyesClosed = true;
    }
    if (_sawEyesClosed && avg >= _blinkOpenThreshold) {
      _sawBlink = true;
    }
  }

  double _yawSwing() {
    if (_yawHistory.length < 3) return 0;
    var minY = _yawHistory.first;
    var maxY = _yawHistory.first;
    for (final y in _yawHistory) {
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    return maxY - minY;
  }

  double _centerJitter(int w, int h) {
    if (_centerXHistory.length < 4) return 0;
    var maxDx = 0.0;
    var maxDy = 0.0;
    for (var i = 1; i < _centerXHistory.length; i++) {
      maxDx = math.max(
        maxDx,
        (_centerXHistory[i] - _centerXHistory[i - 1]).abs(),
      );
      maxDy = math.max(
        maxDy,
        (_centerYHistory[i] - _centerYHistory[i - 1]).abs(),
      );
    }
    return math.max(maxDx, maxDy);
  }
}

enum FaceLivenessState {
  collecting,
  passed,
}

class FaceLivenessUpdate {
  const FaceLivenessUpdate({
    required this.state,
    required this.canRecognize,
    this.hint,
  });

  final FaceLivenessState state;
  final bool canRecognize;
  final String? hint;
}
