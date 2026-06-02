import 'dart:io' show Platform;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Picks one enrollment face when ML Kit returns multiple detections.
///
/// Posters, reflections, and background clutter often produce a tiny secondary
/// face. Android enrollment keeps the largest face unless another is ≥40% of
/// its area (likely a second person).
abstract final class EnrollmentFacePicker {
  EnrollmentFacePicker._();

  static const double _secondaryFaceMinAreaRatio = 0.40;

  static double _boxArea(Face face) {
    final b = face.boundingBox;
    return b.width * b.height;
  }

  /// Returns the face to enroll with, or null if a real second person is present.
  static ({Face? face, int rawCount, int ignoredSpurious}) pick(List<Face> faces) {
    if (faces.isEmpty) {
      return (face: null, rawCount: 0, ignoredSpurious: 0);
    }
    if (faces.length == 1) {
      return (face: faces.first, rawCount: 1, ignoredSpurious: 0);
    }
    if (!Platform.isAndroid) {
      return (face: null, rawCount: faces.length, ignoredSpurious: 0);
    }

    final sorted = List<Face>.from(faces)
      ..sort((a, b) => _boxArea(b).compareTo(_boxArea(a)));
    final primary = sorted.first;
    final primaryArea = _boxArea(primary);
    if (primaryArea <= 1) {
      return (face: primary, rawCount: faces.length, ignoredSpurious: faces.length - 1);
    }

    var ignored = 0;
    for (var i = 1; i < sorted.length; i++) {
      final ratio = _boxArea(sorted[i]) / primaryArea;
      if (ratio >= _secondaryFaceMinAreaRatio) {
        return (face: null, rawCount: faces.length, ignoredSpurious: 0);
      }
      ignored++;
    }
    return (face: primary, rawCount: faces.length, ignoredSpurious: ignored);
  }
}
