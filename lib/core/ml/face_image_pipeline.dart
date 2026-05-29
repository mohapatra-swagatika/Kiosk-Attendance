import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'package:attendance_kiosk_app/core/ml/face_align_geometry.dart';
import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_detection_service.dart';

/// Camera frame → RGB → canonical InsightFace-aligned 112×112 face crop.
///
/// This pipeline is the standard preprocessing required by MobileFaceNet /
/// ArcFace TFLite models. Two key properties make it deterministic across
/// frames and devices, which is critical for high cosine similarity between
/// same-person enrollment and live frames:
///
///   1. **Canonical 5-point eye-anchored alignment** (InsightFace template):
///      the left & right eye landmarks are mapped to fixed coordinates inside
///      a 112×112 output canvas via a similarity transform (rotate + uniform
///      scale + translate). The same face at any distance / tilt produces the
///      same crop — so embeddings line up.
///
///   2. **Deterministic per-frame photometric normalization** (mean/std):
///      every output crop is normalized to a target luminance mean/std,
///      regardless of room lighting, so identical faces in bright vs dim
///      environments produce near-identical embeddings.
class FaceImagePipeline {
  FaceImagePipeline._();

  /// Canonical InsightFace 5-point template (standardized for 112×112).
  /// We use only the eye anchors for robustness — eye landmarks from ML Kit
  /// are far more stable than mouth landmarks at varied head poses.
  static const double _canonLeftEyeX = 38.2946;
  static const double _canonLeftEyeY = 51.6963;
  static const double _canonRightEyeX = 73.5318;
  static const double _canonRightEyeY = 51.5014;

  /// Returns a 112×112 RGB face crop aligned to the InsightFace canonical
  /// eye anchors, or `null` if the eye landmarks are missing / unusable.
  static img.Image? alignedFaceCrop({
    required CameraImage cameraImage,
    required CameraDescription description,
    required Face face,
    int outputSize = 112,
  }) {
    final rgb = _cameraImageToRgb(cameraImage);
    if (rgb == null) return null;
    final geometry = FaceAlignGeometry.fromFace(face);
    if (geometry == null) return null;
    return _canonicalAlign(
      rgb: rgb,
      sourceWidth: cameraImage.width,
      sourceHeight: cameraImage.height,
      description: description,
      geometry: geometry,
      outputSize: outputSize,
    );
  }

  /// Face crop from a cloned [LiveCameraFrame] (safe after async camera callbacks).
  static img.Image? alignedFaceCropFromLiveFrame({
    required LiveCameraFrame frame,
    required CameraDescription description,
    Face? face,
    FaceAlignGeometry? geometry,
    int? mlKitWidth,
    int? mlKitHeight,
    int outputSize = 112,
  }) {
    final resolved = geometry ?? (face != null ? FaceAlignGeometry.fromFace(face) : null);
    if (resolved == null) return null;

    final rgb = _liveFrameToRgb(frame);
    if (rgb == null) return null;
    final dimsW = mlKitWidth ?? mlKitReportedDims(frame).width;
    final dimsH = mlKitHeight ?? mlKitReportedDims(frame).height;
    return _canonicalAlign(
      rgb: rgb,
      sourceWidth: dimsW,
      sourceHeight: dimsH,
      description: description,
      geometry: resolved,
      outputSize: outputSize,
    );
  }

  /// Core alignment: similarity transform driven by eye landmarks +
  /// deterministic photometric normalization. See class doc.
  static img.Image? _canonicalAlign({
    required img.Image rgb,
    required int sourceWidth,
    required int sourceHeight,
    required CameraDescription description,
    required FaceAlignGeometry geometry,
    required int outputSize,
  }) {
    final oriented = _applyCameraRotation(rgb, description);

    final srcLe = _mapPoint(
      geometry.leftEyeX,
      geometry.leftEyeY,
      sourceWidth,
      sourceHeight,
      description,
    );
    final srcRe = _mapPoint(
      geometry.rightEyeX,
      geometry.rightEyeY,
      sourceWidth,
      sourceHeight,
      description,
    );

    final dx = srcRe.x - srcLe.x;
    final dy = srcRe.y - srcLe.y;
    final srcEyeDist = math.sqrt(dx * dx + dy * dy);
    final minEyeDist = Platform.isAndroid ? 12.0 : 18.0;
    if (srcEyeDist < minEyeDist) return null;

    // Target eye positions inside the output canvas.
    final scaleFactor = outputSize / 112.0;
    final tgtLeX = _canonLeftEyeX * scaleFactor;
    final tgtLeY = _canonLeftEyeY * scaleFactor;
    final tgtReX = _canonRightEyeX * scaleFactor;
    final tgtReY = _canonRightEyeY * scaleFactor;
    final tgtMidX = (tgtLeX + tgtReX) / 2;
    final tgtMidY = (tgtLeY + tgtReY) / 2;
    final tgtDx = tgtReX - tgtLeX;
    final tgtDy = tgtReY - tgtLeY;
    final tgtEyeDist = math.sqrt(tgtDx * tgtDx + tgtDy * tgtDy);

    final scale = tgtEyeDist / srcEyeDist;
    // Rotation: source eye line tilt; output line is horizontal. We rotate
    // by -srcAngle to align. Inverse map below uses R(+srcAngle).
    final srcAngle = math.atan2(dy, dx);
    final cosA = math.cos(srcAngle);
    final sinA = math.sin(srcAngle);

    final srcMidX = (srcLe.x + srcRe.x) / 2;
    final srcMidY = (srcLe.y + srcRe.y) / 2;

    final out = img.Image(width: outputSize, height: outputSize);
    final srcW = oriented.width;
    final srcH = oriented.height;
    final invScale = 1.0 / scale;

    for (var v = 0; v < outputSize; v++) {
      final dy0 = (v - tgtMidY) * invScale;
      for (var u = 0; u < outputSize; u++) {
        final dx0 = (u - tgtMidX) * invScale;
        // Rotate dst-relative offset by +srcAngle, then translate to srcMid.
        final sx = dx0 * cosA - dy0 * sinA + srcMidX;
        final sy = dx0 * sinA + dy0 * cosA + srcMidY;
        final color = _bilinearSample(oriented, sx, sy, srcW, srcH);
        out.setPixelRgb(u, v, color.$1, color.$2, color.$3);
      }
    }

    return normalizeForRecognition(out);
  }

  /// Bilinear sample with edge clamping (transparent border → black is bad).
  static (int, int, int) _bilinearSample(
    img.Image src,
    double x,
    double y,
    int w,
    int h,
  ) {
    var cx = x.clamp(0.0, (w - 1).toDouble());
    var cy = y.clamp(0.0, (h - 1).toDouble());
    final x0 = cx.floor();
    final y0 = cy.floor();
    final x1 = math.min(x0 + 1, w - 1);
    final y1 = math.min(y0 + 1, h - 1);
    final fx = cx - x0;
    final fy = cy - y0;

    final p00 = src.getPixel(x0, y0);
    final p10 = src.getPixel(x1, y0);
    final p01 = src.getPixel(x0, y1);
    final p11 = src.getPixel(x1, y1);

    final w00 = (1 - fx) * (1 - fy);
    final w10 = fx * (1 - fy);
    final w01 = (1 - fx) * fy;
    final w11 = fx * fy;

    final r = (p00.r * w00 + p10.r * w10 + p01.r * w01 + p11.r * w11);
    final g = (p00.g * w00 + p10.g * w10 + p01.g * w01 + p11.g * w11);
    final b = (p00.b * w00 + p10.b * w10 + p01.b * w01 + p11.b * w11);
    return (
      r.round().clamp(0, 255),
      g.round().clamp(0, 255),
      b.round().clamp(0, 255),
    );
  }

  /// Deterministic photometric normalization: map per-frame luminance mean/std
  /// onto a fixed target distribution. Same face in any lighting → similar
  /// pixel statistics → similar embedding.
  ///
  /// Bounded scale prevents over-amplifying noise in flat / low-contrast crops.
  static img.Image normalizeForRecognition(img.Image image) {
    const targetMean = 128.0;
    const targetStd = 60.0;
    const minScale = 0.75;
    const maxScale = 1.50;

    var sum = 0.0;
    var sumSq = 0.0;
    final n = image.width * image.height;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final gray = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        sum += gray;
        sumSq += gray * gray;
      }
    }
    final mean = sum / n;
    final variance = math.max(1.0, sumSq / n - mean * mean);
    final std = math.sqrt(variance);

    final rawScale = targetStd / std;
    final scale = rawScale.clamp(minScale, maxScale);
    final offset = targetMean - mean * scale;

    final out = img.Image(width: image.width, height: image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = (p.r * scale + offset).clamp(0, 255).round();
        final g = (p.g * scale + offset).clamp(0, 255).round();
        final b = (p.b * scale + offset).clamp(0, 255).round();
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  /// Kept for backwards compatibility with any callers; same as the new
  /// normalization for now.
  static img.Image enhanceForRecognition(img.Image image) =>
      normalizeForRecognition(image);

  /// Converts an `img.Image` (112x112 RGB) to a TFLite input buffer of shape
  /// `[1, size, size, 3]` with values in `[-1, 1]`.
  static List<List<List<List<double>>>> toModelInput(
    img.Image image, {
    int size = 112,
  }) {
    final input = List.generate(
      1,
      (_) => List.generate(
        size,
        (_) => List.generate(size, (_) => List<double>.filled(3, 0)),
      ),
    );
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = image.getPixel(x, y);
        input[0][y][x][0] = (p.r - 127.5) / 127.5;
        input[0][y][x][1] = (p.g - 127.5) / 127.5;
        input[0][y][x][2] = (p.b - 127.5) / 127.5;
      }
    }
    return input;
  }

  // ---------------------------------------------------------------------------
  // Frame → RGB conversion
  // ---------------------------------------------------------------------------

  static img.Image? _liveFrameToRgb(LiveCameraFrame frame) {
    switch (frame.format) {
      case LiveCameraImageFormat.bgra8888:
        return _bgraBytesToRgb(
          frame.bytes,
          frame.width,
          frame.height,
          frame.bytesPerRow,
        );
      case LiveCameraImageFormat.nv21:
        return _nv21BytesToRgb(frame.bytes, frame.width, frame.height);
    }
  }

  static img.Image _bgraBytesToRgb(
    Uint8List bytes,
    int w,
    int h,
    int bytesPerRow,
  ) {
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final row = y * bytesPerRow;
      for (var x = 0; x < w; x++) {
        final i = row + x * 4;
        if (i + 2 >= bytes.length) continue;
        out.setPixelRgb(x, y, bytes[i + 2], bytes[i + 1], bytes[i]);
      }
    }
    return out;
  }

  static img.Image _nv21BytesToRgb(Uint8List y0, int w, int h) {
    final out = img.Image(width: w, height: h);
    final ySize = w * h;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final yIndex = y * w + x;
        if (yIndex >= y0.length) continue;
        final yVal = y0[yIndex] & 0xff;
        var uVal = 128;
        var vVal = 128;
        if (y0.length > ySize) {
          final uvRow = (y >> 1) * w;
          final uvCol = (x >> 1) << 1;
          final vIdx = ySize + uvRow + uvCol;
          final uIdx = vIdx + 1;
          if (uIdx < y0.length) {
            vVal = y0[vIdx] & 0xff;
            uVal = y0[uIdx] & 0xff;
          }
        }
        final rgb = _yuvToRgb(yVal, uVal, vVal);
        out.setPixelRgb(x, y, rgb.$1, rgb.$2, rgb.$3);
      }
    }
    return out;
  }

  static img.Image? _cameraImageToRgb(CameraImage image) {
    if (Platform.isAndroid) {
      if (image.format.group == ImageFormatGroup.nv21 ||
          image.planes.length == 1) {
        return _nv21ToRgb(image);
      }
      if (image.format.group == ImageFormatGroup.yuv420 &&
          image.planes.length >= 3) {
        return _yuv420ToRgb(image);
      }
      return null;
    }
    if (Platform.isIOS) {
      if (image.format.group == ImageFormatGroup.bgra8888 &&
          image.planes.isNotEmpty) {
        return _bgraToRgb(image);
      }
      return null;
    }
    return null;
  }

  static img.Image _bgraToRgb(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final bytes = image.planes.first.bytes;
    final bytesPerRow = image.planes.first.bytesPerRow;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final row = y * bytesPerRow;
      for (var x = 0; x < w; x++) {
        final i = row + x * 4;
        final b = bytes[i];
        final g = bytes[i + 1];
        final r = bytes[i + 2];
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  static img.Image _nv21ToRgb(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final y0 = image.planes.first.bytes;
    final out = img.Image(width: w, height: h);
    final ySize = w * h;
    final vu = y0.length > ySize ? y0 : null;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final yIndex = y * w + x;
        if (yIndex >= y0.length) continue;
        final yVal = y0[yIndex] & 0xff;
        var uVal = 128;
        var vVal = 128;
        if (vu != null) {
          final uvRow = (y >> 1) * w;
          final uvCol = (x >> 1) << 1;
          final vIdx = ySize + uvRow + uvCol;
          final uIdx = vIdx + 1;
          if (uIdx < vu.length) {
            vVal = vu[vIdx] & 0xff;
            uVal = vu[uIdx] & 0xff;
          }
        }
        final rgb = _yuvToRgb(yVal, uVal, vVal);
        out.setPixelRgb(x, y, rgb.$1, rgb.$2, rgb.$3);
      }
    }
    return out;
  }

  static img.Image _yuv420ToRgb(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yRow = yPlane.bytesPerRow;
    final uRow = uPlane.bytesPerRow;
    final uPixel = uPlane.bytesPerPixel ?? 1;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final yIdx = y * yRow + x;
        if (yIdx >= yPlane.bytes.length) continue;
        final yVal = yPlane.bytes[yIdx] & 0xff;
        final uvIdx = (y >> 1) * uRow + (x >> 1) * uPixel;
        var uVal = 128;
        var vVal = 128;
        if (uvIdx < uPlane.bytes.length && uvIdx < vPlane.bytes.length) {
          uVal = uPlane.bytes[uvIdx] & 0xff;
          vVal = vPlane.bytes[uvIdx] & 0xff;
        }
        final rgb = _yuvToRgb(yVal, uVal, vVal);
        out.setPixelRgb(x, y, rgb.$1, rgb.$2, rgb.$3);
      }
    }
    return out;
  }

  static (int, int, int) _yuvToRgb(int y, int u, int v) {
    final c = y - 16;
    final d = u - 128;
    final e = v - 128;
    final r = ((1192 * c + 1634 * e) >> 10).clamp(0, 255);
    final g = ((1192 * c - 833 * e - 400 * d) >> 10).clamp(0, 255);
    final b = ((1192 * c + 2066 * d) >> 10).clamp(0, 255);
    return (r, g, b);
  }

  // ---------------------------------------------------------------------------
  // Sensor orientation handling (front camera is mirrored)
  // ---------------------------------------------------------------------------

  static img.Image _applyCameraRotation(img.Image src, CameraDescription d) {
    final rotation = d.sensorOrientation;
    img.Image rotated = src;
    if (rotation != 0) {
      rotated = img.copyRotate(src, angle: rotation.toDouble());
    }
    if (d.lensDirection == CameraLensDirection.front) {
      rotated = img.flipHorizontal(rotated);
    }
    return rotated;
  }

  static _Point _mapPoint(
    double x,
    double y,
    int srcW,
    int srcH,
    CameraDescription d,
  ) {
    var px = x;
    var py = y;
    final rot = d.sensorOrientation;

    if (Platform.isAndroid) {
      // Landmarks are already in ML Kit upright space; [srcW/srcH] must be
      // mlKitReportedDims (see alignedFaceCropFromLiveFrame). Mirror once to
      // match the horizontal flip in `_applyCameraRotation`.
      if (d.lensDirection == CameraLensDirection.front) {
        px = srcW - px;
      }
      return _Point(px, py);
    }

    // iOS: ML Kit returns coordinates in the raw buffer space.
    switch (rot) {
      case 90:
        final nx = srcH - py;
        final ny = px;
        px = nx;
        py = ny;
        break;
      case 180:
        px = srcW - px;
        py = srcH - py;
        break;
      case 270:
        final nx = py;
        final ny = srcW - px;
        px = nx;
        py = ny;
        break;
    }

    if (d.lensDirection == CameraLensDirection.front) {
      final rotatedW = (rot == 90 || rot == 270) ? srcH : srcW;
      px = rotatedW - px;
    }
    return _Point(px, py);
  }
}

class _Point {
  const _Point(this.x, this.y);
  final double x;
  final double y;
}

/// Helper: dump RGB image to a Float32List input buffer in `[-1, 1]` range.
Float32List rgbImageToFloat32(img.Image image, {int size = 112}) {
  final buffer = Float32List(size * size * 3);
  var i = 0;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final p = image.getPixel(x, y);
      buffer[i++] = (p.r - 127.5) / 127.5;
      buffer[i++] = (p.g - 127.5) / 127.5;
      buffer[i++] = (p.b - 127.5) / 127.5;
    }
  }
  return buffer;
}
