import 'dart:io' show Platform;
import 'dart:ui' show Offset;

/// Low-pass filter for face center — reduces jitter on Android ML Kit streams.
class FaceTrackSmoother {
  FaceTrackSmoother();

  double? _x;
  double? _y;

  /// Higher = snappier; lower = smoother. Android-only tuning in [smooth].
  static double get _alpha => Platform.isAndroid ? 0.42 : 0.35;

  /// Returns smoothed center in the same coordinate space as input.
  Offset smooth(double x, double y) {
    if (_x == null || _y == null) {
      _x = x;
      _y = y;
      return Offset(x, y);
    }
    _x = _x! + (x - _x!) * _alpha;
    _y = _y! + (y - _y!) * _alpha;
    return Offset(_x!, _y!);
  }

  void reset() {
    _x = null;
    _y = null;
  }
}
