import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:attendance_kiosk_app/core/ml/face_align_geometry.dart';
import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/core/ml/face_embed_preprocess.dart';
import 'package:attendance_kiosk_app/core/ml/face_image_pipeline.dart';
import 'package:attendance_kiosk_app/core/ml/face_match_debug_log.dart';
import 'package:attendance_kiosk_app/core/ml/face_ml_serial.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_detection_service.dart';

/// Result of a MobileFaceNet capture: embedding plus the aligned crop used.
class FaceEmbeddingCapture {
  const FaceEmbeddingCapture({required this.embedding, required this.crop});

  final List<double> embedding;
  final img.Image crop;
}

/// Wraps a MobileFaceNet TFLite model loaded from `assets/models/`.
///
/// Lifecycle:
///   * call [initialize] once at app start
///   * check [isReady] before calling [embedFace]
///   * call [dispose] when shutting down (optional in app lifetimes)
class TfliteFaceEmbedder {
  TfliteFaceEmbedder();

  static const String _modelAssetPath = 'assets/models/mobile_face_net.tflite';

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  bool _initialized = false;
  bool _loadAttempted = false;
  bool _imagePipelineWarmed = false;
  int _inputSize = 112;
  int _outputDim = 192;
  String? _loadError;
  Completer<void>? _inferLock;

  bool get isReady => _initialized && _interpreter != null;
  int get outputDim => _outputDim;
  int get inputSize => _inputSize;
  String? get loadError => _loadError;

  Future<bool> initialize() async {
    if (_loadAttempted) return isReady;
    _loadAttempted = true;
    try {
      final interpreter = await Interpreter.fromAsset(_modelAssetPath);
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      final inShape = inputTensor.shape;
      final outShape = outputTensor.shape;

      if (inShape.length != 4 || inShape[1] != inShape[2] || inShape[3] != 3) {
        _loadError =
            'Unexpected model input shape $inShape (need [1, N, N, 3]). Replace mobile_face_net.tflite.';
        FaceMatchDebugLog.log('[FaceEmbedder] $_loadError');
        interpreter.close();
        return false;
      }
      if (outShape.length != 2) {
        _loadError = 'Unexpected model output shape $outShape (need [1, D]).';
        FaceMatchDebugLog.log('[FaceEmbedder] $_loadError');
        interpreter.close();
        return false;
      }

      _inputSize = inShape[1];
      _outputDim = outShape[1];
      _interpreter = interpreter;
      _initialized = true;

      try {
        _isolateInterpreter = await IsolateInterpreter.create(
          address: interpreter.address,
        );
      } catch (e) {
        FaceMatchDebugLog.log(
          '[FaceEmbedder] IsolateInterpreter unavailable: $e (running on main)',
        );
        _isolateInterpreter = null;
      }

      final msg =
          'MobileFaceNet loaded — input=[1, $_inputSize, $_inputSize, 3] '
          'output=[1, $_outputDim] '
          '${_isolateInterpreter != null ? "(isolate)" : "(main)"}';
      FaceMatchDebugLog.log('[FaceEmbedder] $msg');
      if (kDebugMode) debugPrint('[FaceEmbedder] $msg');
      return true;
    } catch (e) {
      _loadError = e.toString();
      final msg =
          'MobileFaceNet NOT loaded ($_modelAssetPath missing or invalid). Falling back to ML Kit contour embeddings. Details: $_loadError';
      FaceMatchDebugLog.log('[FaceEmbedder] $msg');
      if (kDebugMode) debugPrint('[FaceEmbedder] $msg');
      return false;
    }
  }

  /// JITs NV21/BGRA → align → normalize on a worker isolate (not the UI thread).
  Future<void> warmUpImagePipeline() async {
    if (!isReady || _imagePipelineWarmed) return;
    await preprocessEmbedInput(
      FaceEmbedPreprocessInput.synthetic(outputSize: _inputSize),
    );
    _imagePipelineWarmed = true;
  }

  /// Runs one dummy inference so the first live unlock does not stall the UI.
  Future<void> warmUpInference() async {
    if (!isReady) return;
    await warmUpImagePipeline();

    await FaceMlEmbedSerial.runKiosk(() async {
      final input = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (_) => List.generate(_inputSize, (_) => List.filled(3, 0.0)),
        ),
      );
      final output = List.generate(1, (_) => List.filled(_outputDim, 0.0));

      final iso = _isolateInterpreter;
      try {
        if (iso != null) {
          while (_inferLock != null) {
            await _inferLock!.future;
          }
          final lock = Completer<void>();
          _inferLock = lock;
          try {
            await iso.run(input, output);
          } finally {
            _inferLock = null;
            lock.complete();
          }
        } else {
          _interpreter!.run(input, output);
        }
      } catch (e) {
        FaceMatchDebugLog.log('[FaceEmbedder] warm-up inference: $e');
      }
    });
  }

  /// Generates a 192-dim L2-normalized embedding from a live camera frame + ML Kit face.
  ///
  /// Returns both the embedding and the aligned crop so callers can run
  /// quality checks (blur/lighting) without re-decoding the frame.
  Future<FaceEmbeddingCapture?> embed({
    required CameraImage cameraImage,
    required CameraDescription description,
    required Face face,
  }) async {
    if (!isReady) return null;

    final crop = FaceImagePipeline.alignedFaceCrop(
      cameraImage: cameraImage,
      description: description,
      face: face,
      outputSize: _inputSize,
    );
    return await _embedFromCrop(crop);
  }

  /// Prefer this during live camera streams — uses bytes copied before any `await`.
  Future<FaceEmbeddingCapture?> embedFromLiveFrame({
    required LiveCameraFrame frame,
    required CameraDescription description,
    required Face face,
  }) async {
    if (!isReady) return null;

    final geometry = FaceAlignGeometry.fromFace(face);
    if (geometry == null) return null;

    final dims = mlKitReportedDims(frame);
    final flat = await preprocessEmbedInput(
      FaceEmbedPreprocessInput(
        bytes: frame.bytes,
        width: frame.width,
        height: frame.height,
        rotationDegrees: frame.rotationDegrees,
        bytesPerRow: frame.bytesPerRow,
        format: frame.format,
        sensorOrientation: description.sensorOrientation,
        lensDirection: description.lensDirection,
        mlKitWidth: dims.width,
        mlKitHeight: dims.height,
        geometry: geometry,
        outputSize: _inputSize,
      ),
    );
    if (flat == null) return null;

    return _embedFromFlatInput(flat);
  }

  Future<FaceEmbeddingCapture?> _embedFromCrop(img.Image? crop) async {
    if (crop == null) return null;
    final flat = rgbImageToFloat32(crop, size: _inputSize);
    return _embedFromFlatInput(flat);
  }

  Future<FaceEmbeddingCapture?> _embedFromFlatInput(Float32List flat) async {
    final input = _flatToModelInput(flat, _inputSize);
    final output = List.generate(1, (_) => List<double>.filled(_outputDim, 0));

    final iso = _isolateInterpreter;
    try {
      if (iso != null) {
        // Serialize concurrent embed calls — IsolateInterpreter rejects
        // overlapping run() invocations.
        while (_inferLock != null) {
          await _inferLock!.future;
        }
        final lock = Completer<void>();
        _inferLock = lock;
        try {
          await iso.run(input, output);
        } finally {
          _inferLock = null;
          lock.complete();
        }
      } else {
        _interpreter!.run(input, output);
      }
    } catch (e) {
      FaceMatchDebugLog.log('[FaceEmbedder] inference error: $e');
      return null;
    }

    return FaceEmbeddingCapture(
      embedding: _l2Normalize(output[0]),
      crop: img.Image(width: _inputSize, height: _inputSize),
    );
  }

  static List<List<List<List<double>>>> _flatToModelInput(
    Float32List flat,
    int size,
  ) {
    final input = List.generate(
      1,
      (_) => List.generate(
        size,
        (_) => List.generate(size, (_) => List<double>.filled(3, 0)),
      ),
    );
    var i = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        input[0][y][x][0] = flat[i++];
        input[0][y][x][1] = flat[i++];
        input[0][y][x][2] = flat[i++];
      }
    }
    return input;
  }

  /// Backwards-compatible API for older callers — returns only the vector.
  Future<List<double>?> embedFace({
    required CameraImage cameraImage,
    required CameraDescription description,
    required Face face,
  }) async {
    final capture = await embed(
      cameraImage: cameraImage,
      description: description,
      face: face,
    );
    return capture?.embedding;
  }

  Future<void> dispose() async {
    try {
      await _isolateInterpreter?.close();
    } catch (_) {}
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }

  static List<double> _l2Normalize(List<double> v) {
    var norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = math.sqrt(norm);
    if (norm < 1e-9) return v;
    return v.map((e) => e / norm).toList();
  }
}
