import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android screen pinning / Lock Task. iOS uses Guided Access (user-controlled).
class KioskModeChannel {
  static const MethodChannel _channel = MethodChannel('com.example.attendance_kiosk_app/kiosk');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> enterKioskMode() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('enterKiosk');
      return result ?? false;
    } on PlatformException catch (e, st) {
      debugPrint('enterKioskMode: $e\n$st');
      return false;
    }
  }

  Future<bool> exitKioskMode() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('exitKiosk');
      return result ?? false;
    } on PlatformException catch (e, st) {
      debugPrint('exitKioskMode: $e\n$st');
      return false;
    }
  }
}
