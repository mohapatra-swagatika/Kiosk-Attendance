import 'dart:async';
import 'dart:io' show Platform;

/// Serializes ML Kit face detection (one [FaceDetector] instance at a time).
class FaceMlDetectSerial {
  FaceMlDetectSerial._();

  static Future<void> _tail = Future<void>.value();

  static Future<T> run<T>(
    Future<T> Function() action, {
    Duration timeout = const Duration(milliseconds: 650),
  }) =>
      runWithTimeout(action, timeout: timeout);

  /// Face ID enrollment detect — platform-aware timeout.
  static Future<T> runEnrollment<T>(
    Future<T> Function() action,
  ) =>
      runWithTimeout(
        action,
        timeout: Platform.isAndroid
            ? const Duration(milliseconds: 380)
            : const Duration(milliseconds: 650),
      );

  /// One-time ML Kit model load (still frame before live stream).
  static Future<T> runEnrollmentPrime<T>(
    Future<T> Function() action,
  ) =>
      runWithTimeout(
        action,
        timeout: const Duration(seconds: 18),
      );

  /// Kiosk unlock — shorter detect timeout for instant response.
  static Future<T> runKiosk<T>(
    Future<T> Function() action,
  ) =>
      runWithTimeout(
        action,
        timeout: Platform.isAndroid
            ? const Duration(milliseconds: 260)
            : const Duration(milliseconds: 320),
      );

  /// One-time ML Kit model load for kiosk (still frame before live stream).
  static Future<T> runKioskPrime<T>(
    Future<T> Function() action,
  ) =>
      runWithTimeout(
        action,
        timeout: const Duration(seconds: 18),
      );

  static Future<T> runWithTimeout<T>(
    Future<T> Function() action, {
    required Duration timeout,
  }) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(
          await action().timeout(
            timeout,
            onTimeout: () => throw TimeoutException('ML Kit detect', timeout),
          ),
        );
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }
}

/// Serializes TFLite inference (interpreter is not thread-safe).
class FaceMlEmbedSerial {
  FaceMlEmbedSerial._();

  static Future<void> _tail = Future<void>.value();

  static Future<T> run<T>(
    Future<T> Function() action, {
    Duration timeout = const Duration(milliseconds: 1200),
  }) =>
      runWithTimeout(action, timeout: timeout);

  /// Kiosk unlock — faster embedding path.
  static Future<T> runKiosk<T>(
    Future<T> Function() action,
  ) =>
      runWithTimeout(
        action,
        timeout: Platform.isAndroid
            ? const Duration(milliseconds: 480)
            : const Duration(milliseconds: 550),
      );

  /// Enrollment embedding — Android allows slightly less time (fast detect cadence).
  static Future<T> runEnrollmentEmbed<T>(
    Future<T> Function() action,
  ) =>
      runWithTimeout(
        action,
        timeout: Platform.isAndroid
            ? const Duration(milliseconds: 950)
            : const Duration(milliseconds: 1200),
      );

  static Future<T> runWithTimeout<T>(
    Future<T> Function() action, {
    required Duration timeout,
  }) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(
          await action().timeout(
            timeout,
            onTimeout: () => throw TimeoutException('TFLite embed', timeout),
          ),
        );
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }
}

/// @deprecated Use [FaceMlDetectSerial] or [FaceMlEmbedSerial].
typedef FaceMlSerial = FaceMlDetectSerial;
