import 'dart:async';

import 'package:camera/camera.dart';

/// Keeps only the latest camera frame when ML is busy (prevents backlog / frozen preview).
///
/// The camera plugin delivers frames on a background thread; this coordinator
/// ensures we never queue unbounded work on the UI isolate.
class CameraFramePipeline {
  CameraFramePipeline();

  bool _processing = false;
  bool _paused = false;
  _FrameJob? _pending;

  bool get isPaused => _paused;

  void pause() => _paused = true;

  void resume() => _paused = false;

  /// Submit a frame. If [processor] is still running, the newest frame replaces
  /// any previously dropped pending frame.
  void submit({
    required CameraImage image,
    required Future<void> Function(CameraImage image) processor,
  }) {
    if (_paused) return;
    if (_processing) {
      _pending = _FrameJob(image, processor);
      return;
    }
    _processing = true;
    unawaited(_run(image, processor));
  }

  Future<void> _run(
    CameraImage image,
    Future<void> Function(CameraImage image) processor,
  ) async {
    if (_paused) {
      _finishCycle();
      return;
    }
    try {
      await processor(image);
    } catch (_) {
      // Transient ML/camera errors — next frame recovers.
    } finally {
      _finishCycle();
    }
  }

  void _finishCycle() {
    final pending = _pending;
    _pending = null;
    _processing = false;
    if (pending != null && !_paused) {
      _processing = true;
      unawaited(_run(pending.image, pending.processor));
    }
  }

  void reset() {
    _pending = null;
    _processing = false;
    _paused = false;
  }
}

class _FrameJob {
  _FrameJob(this.image, this.processor);

  final CameraImage image;
  final Future<void> Function(CameraImage image) processor;
}
