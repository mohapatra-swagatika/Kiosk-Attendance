import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:attendance_kiosk_app/app/bootstrap.dart' show appFaceEmbedder;
import 'package:attendance_kiosk_app/core/ml/android_ml_tuning.dart';
import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_recognition_trace.dart';
import 'package:attendance_kiosk_app/core/ml/tflite_face_embedder.dart';

/// Profile key — NV21 rotate/flip variant used at enrollment (Android only).
const String kAndroidNv21AlignProfileKey = 'androidNv21Align';

/// Android front-camera NV21 alignment variants (landmarks ↔ RGB pixels).
enum AndroidNv21AlignMode {
  rotWithFlip,
  rotNoFlip,
  invRotWithFlip,
  invRotNoFlip,
}

/// Android NV21 embed alignment (enrollment + kiosk). iOS uses the default path only.
abstract final class AndroidNv21AlignCalibrator {
  AndroidNv21AlignCalibrator._();

  static const AndroidNv21AlignMode _enrollmentMode = AndroidNv21AlignMode.rotWithFlip;

  static AndroidNv21AlignMode? _enrollmentLocked;

  static void resetEnrollment() {
    _enrollmentLocked = null;
  }

  static int? get enrollmentLockedIndex =>
      (_enrollmentLocked ?? _enrollmentMode).index;

  static AndroidNv21AlignMode modeFromProfile(Map<String, dynamic> profile) {
    final raw = profile[kAndroidNv21AlignProfileKey];
    if (raw is int && raw >= 0 && raw < AndroidNv21AlignMode.values.length) {
      return AndroidNv21AlignMode.values[raw];
    }
    return _enrollmentMode;
  }

  /// Most common [kAndroidNv21AlignProfileKey] among enrolled profiles (new enrolls).
  static AndroidNv21AlignMode? dominantGalleryAlignMode(
    Map<String, Map<String, dynamic>> gallery,
  ) {
    final counts = <int, int>{};
    for (final profile in gallery.values) {
      final raw = profile[kAndroidNv21AlignProfileKey];
      if (raw is! int || raw < 0 || raw >= AndroidNv21AlignMode.values.length) {
        continue;
      }
      counts[raw] = (counts[raw] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final top = counts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return AndroidNv21AlignMode.values[top.key];
  }

  static Map<AndroidNv21AlignMode, int> galleryAlignModeCounts(
    Map<String, Map<String, dynamic>> gallery,
  ) {
    final counts = <AndroidNv21AlignMode, int>{};
    for (final profile in gallery.values) {
      final raw = profile[kAndroidNv21AlignProfileKey];
      if (raw is! int || raw < 0 || raw >= AndroidNv21AlignMode.values.length) {
        continue;
      }
      final mode = AndroidNv21AlignMode.values[raw];
      counts[mode] = (counts[mode] ?? 0) + 1;
    }
    return counts;
  }

  /// Enrollment — lock NV21 mode after the first sample using prior-embedding agreement.
  static Future<FaceEmbeddingCapture?> embedEnrollment({
    required LiveCameraFrame frame,
    required CameraDescription description,
    required Face face,
    required List<List<double>> priorEmbeddings,
  }) async {
    if (!Platform.isAndroid || !appFaceEmbedder.isReady) {
      return appFaceEmbedder.embedFromLiveFrame(
        frame: frame,
        description: description,
        face: face,
      );
    }

    // One NV21 mode for the whole session — mid-session calibration mixed alignments
    // and broke kiosk matching against the stored profile.
    _enrollmentLocked ??= _enrollmentMode;
    final mode = _enrollmentLocked!;
    return appFaceEmbedder.embedFromLiveFrame(
      frame: frame,
      description: description,
      face: face,
      androidAlign: mode,
    );
  }

  /// Kiosk embed + aligned crop (for sharpness gate).
  static Future<FaceEmbeddingCapture?> embedKioskCapture({
    required LiveCameraFrame frame,
    required CameraDescription description,
    required Face face,
    required Map<String, Map<String, dynamic>> gallery,
  }) async {
    if (!Platform.isAndroid || !appFaceEmbedder.isReady) {
      return appFaceEmbedder.embedFromLiveFrame(
        frame: frame,
        description: description,
        face: face,
      );
    }

    if (gallery.isNotEmpty) {
      final counts = galleryAlignModeCounts(gallery);
      final dominant = dominantGalleryAlignMode(gallery) ?? _enrollmentMode;

      // If the gallery contains mixed NV21 alignment modes, using only the dominant
      // mode can produce low similarity for employees enrolled under a different
      // mode. In that case, do a small search across modes (bounded for perf).
      final mixed = counts.length > 1;
      final shouldSearch = mixed && gallery.length <= 10;

      if (!shouldSearch) {
        return appFaceEmbedder.embedFromLiveFrame(
          frame: frame,
          description: description,
          face: face,
          androidAlign: dominant,
        );
      }

      FaceEmbeddingCapture? bestCap;
      var bestMargin = -1.0;
      var bestScore = 0.0;
      String? bestEmployeeId;
      AndroidNv21AlignMode? bestMode;
      for (final mode in AndroidNv21AlignMode.values) {
        final capture = await appFaceEmbedder.embedFromLiveFrame(
          frame: frame,
          description: description,
          face: face,
          androidAlign: mode,
        );
        if (capture == null) continue;
        final outcome = FaceEmbeddingCodec.matchProbe(
          probe: capture.embedding,
          gallery: gallery,
        );
        final margin = outcome.margin;
        final score = outcome.bestScore;
        if (margin < AndroidMlTuning.kioskAlignSearchMinMargin) continue;
        if (margin > bestMargin || (margin == bestMargin && score > bestScore)) {
          bestMargin = margin;
          bestScore = score;
          bestCap = capture;
          bestMode = mode;
          bestEmployeeId = outcome.bestEmployeeId;
        }
      }

      if (bestCap != null) {
        if (kDebugMode || FaceRecognitionTrace.kioskTraceEnabled) {
          FaceRecognitionTrace.log(
            'ANDROID_ALIGN',
            'kiosk mixed dominant=$dominant chosen=$bestMode '
            'employee=$bestEmployeeId score=${bestScore.toStringAsFixed(4)} '
            'margin=${bestMargin.toStringAsFixed(4)} counts=$counts',
          );
        }
        return bestCap;
      }

      return appFaceEmbedder.embedFromLiveFrame(
        frame: frame,
        description: description,
        face: face,
        androidAlign: dominant,
      );
    }

    FaceEmbeddingCapture? bestCap;
    var bestMargin = -1.0;
    var bestScore = 0.0;
    String? bestEmployeeId;
    AndroidNv21AlignMode? bestMode;
    for (final mode in AndroidNv21AlignMode.values) {
      final capture = await appFaceEmbedder.embedFromLiveFrame(
        frame: frame,
        description: description,
        face: face,
        androidAlign: mode,
      );
      if (capture == null) continue;
      final outcome = FaceEmbeddingCodec.matchProbe(
        probe: capture.embedding,
        gallery: gallery,
      );
      final margin = outcome.margin;
      final score = outcome.bestScore;
      if (margin < AndroidMlTuning.kioskAlignSearchMinMargin) continue;
      if (margin > bestMargin || (margin == bestMargin && score > bestScore)) {
        bestMargin = margin;
        bestScore = score;
        bestCap = capture;
        bestMode = mode;
        bestEmployeeId = outcome.bestEmployeeId;
      }
    }

    if (bestCap != null) {
      if (kDebugMode || FaceRecognitionTrace.kioskTraceEnabled) {
        FaceRecognitionTrace.log(
          'ANDROID_ALIGN',
          'kiosk search=$bestMode employee=$bestEmployeeId '
          'score=${bestScore.toStringAsFixed(4)} margin=${bestMargin.toStringAsFixed(4)}',
        );
      }
      return bestCap;
    }

    return appFaceEmbedder.embedFromLiveFrame(
      frame: frame,
      description: description,
      face: face,
      androidAlign: _enrollmentMode,
    );
  }

  /// Kiosk — use gallery's dominant align mode, or margin-safe search (not raw max score).
  static Future<List<double>?> embedKioskProbe({
    required LiveCameraFrame frame,
    required CameraDescription description,
    required Face face,
    required Map<String, Map<String, dynamic>> gallery,
  }) async {
    final cap = await embedKioskCapture(
      frame: frame,
      description: description,
      face: face,
      gallery: gallery,
    );
    if (cap == null) return null;

    final dominant = dominantGalleryAlignMode(gallery);
    if (kDebugMode && dominant != null) {
      final outcome = FaceEmbeddingCodec.matchProbe(
        probe: cap.embedding,
        gallery: gallery,
      );
      FaceRecognitionTrace.log(
        'ANDROID_ALIGN',
        'kiosk dominant=$dominant best=${outcome.bestEmployeeId} '
        'score=${outcome.bestScore.toStringAsFixed(4)} '
        'margin=${outcome.margin.toStringAsFixed(4)}',
      );
    }
    return cap.embedding;
  }
}
