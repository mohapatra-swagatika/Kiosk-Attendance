import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:attendance_kiosk_app/core/firebase/firebase_bootstrap.dart';

/// Defers Firebase Core until after the first interactive frame (registration).
///
/// Kiosk face recognition awaits [whenReady] before opening the camera / ML Kit.
class FirebaseReadiness {
  FirebaseReadiness._();

  static final FirebaseReadiness instance = FirebaseReadiness._();

  Completer<void>? _ready;
  Object? _error;
  bool _started = false;

  bool get isReady => _ready?.isCompleted == true && _error == null;

  bool get hasFailed => _error != null;

  Object? get error => _error;

  /// Starts Firebase init on a background microtask (safe to call multiple times).
  void scheduleInit() {
    if (_started) return;
    _started = true;
    _ready = Completer<void>();
    scheduleMicrotask(_run);
  }

  Future<void> _run() async {
    try {
      await initializeFirebaseCore();
      _ready?.complete();
      if (kDebugMode) {
        debugPrint('FirebaseReadiness: ready');
      }
    } catch (e, st) {
      _error = e;
      _ready?.completeError(e, st);
      if (kDebugMode) {
        debugPrint('FirebaseReadiness: failed — $e');
      }
    }
  }

  /// Waits until Firebase Core has finished initializing.
  Future<void> whenReady() async {
    if (isReady) return;
    scheduleInit();
    final completer = _ready;
    if (completer == null) return;
    await completer.future;
  }
}
