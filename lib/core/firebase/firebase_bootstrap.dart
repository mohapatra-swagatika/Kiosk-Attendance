import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:attendance_kiosk_app/firebase_options.dart';

/// Initializes Firebase Core + Installations before ML Kit / camera start.
///
/// [FirebaseInstallations] registers the native `CCTPolicyVending_API` binding
/// that ML Kit's Google telemetry layer requires on iOS (without Analytics).
Future<void> initializeFirebaseCore() async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException(
          'Firebase.initializeApp timed out after 8s',
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Firebase.initializeApp failed: $e\n$st');
      }
      rethrow;
    }
  } else if (kDebugMode) {
    debugPrint('Firebase Core already configured (native AppDelegate)');
  }

  // Registers CCT / policy vendor bindings used by ML Kit + GoogleDataTransport.
  try {
    // Do not block app startup on this call. On some iOS devices, this can take
    // seconds on first install and makes the Registration screen feel frozen.
    //
    // We still kick it off so ML Kit's GoogleDataTransport can bind later.
    // Ignore failures — ML features will handle missing telemetry.
    unawaited(
      FirebaseInstallations.instance
          .getId()
          .timeout(const Duration(seconds: 5)),
    );
    if (kDebugMode) {
      debugPrint(
        'Firebase Installations ready (${DefaultFirebaseOptions.currentPlatform.projectId})',
      );
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('FirebaseInstallations.getId (non-fatal): $e');
    }
  }
}
