import 'package:flutter/scheduler.dart';

/// Yields to the Flutter event loop so loading animations can paint between
/// heavy native calls (camera, TFLite, Firebase).
Future<void> yieldToUi({int frames = 1}) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(Duration.zero);
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.idle) {
      await binding.endOfFrame;
    }
  }
}
