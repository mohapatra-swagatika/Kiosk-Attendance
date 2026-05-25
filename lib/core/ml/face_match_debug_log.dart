import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Console debug output for face registration / matching (see Flutter run log).
class FaceMatchDebugLog {
  FaceMatchDebugLog._();

  static final List<String> _lines = [];

  static List<String> get lines => List.unmodifiable(_lines);

  static void clear() => _lines.clear();

  static void log(String message) {
    _lines.add(message);
    if (kDebugMode) {
      debugPrint('[FaceMatch] $message');
    }
  }

  static void logProfileSummary({
    required String label,
    required String employeeId,
    required Map<String, dynamic> profile,
  }) {
    log('── $label: employeeId=$employeeId, v=${profile['v']} ──');
    for (final pose in ['straight', 'left', 'right']) {
      final raw = profile[pose];
      if (raw is! List) {
        log('  $pose: (missing)');
        continue;
      }
      final vec = raw.map((e) => (e as num).toDouble()).toList();
      final preview = vec.take(6).map((e) => e.toStringAsFixed(4)).join(', ');
      log('  $pose: dim=${vec.length} first=[$preview…]');
    }
    final yaws = <String>[];
    for (final key in ['yawStraight', 'yawLeft', 'yawRight']) {
      if (profile[key] != null) yaws.add('$key=${profile[key]}');
    }
    if (yaws.isNotEmpty) log('  ${yaws.join(', ')}');
  }

  static void logPoseComparison({
    required String registeringId,
    required String galleryId,
    required Map<String, double> cosineByPose,
    required Map<String, double> meanAbsDiffByPose,
    required double intraPoseMinCosine,
  }) {
    log('Compare NEW($registeringId) vs STORED($galleryId):');
  for (final pose in ['straight', 'left', 'right']) {
      final c = cosineByPose[pose];
      final d = meanAbsDiffByPose[pose];
      if (c == null) {
        log('  $pose: skipped (dimension mismatch or missing)');
      } else {
        log('  $pose: cosine=${c.toStringAsFixed(4)} meanAbsDiff=${d?.toStringAsFixed(4) ?? "n/a"}');
      }
    }
    log('  NEW profile intra-pose min cosine (straight/left/right): '
        '${intraPoseMinCosine.toStringAsFixed(4)}');
  }

  static String lastReportAsText() => _lines.join('\n');

  static String vectorPreview(List<double> v, {int count = 8}) {
    if (v.isEmpty) return '[]';
    final p = v.take(count).map((e) => e.toStringAsFixed(4)).join(', ');
    return '[$p${v.length > count ? '…' : ''}] (${v.length}d)';
  }

  static String profileJsonPreview(Map<String, dynamic> profile) {
    try {
      final slim = <String, dynamic>{
        'v': profile['v'],
        for (final p in ['straight', 'left', 'right'])
          if (profile[p] is List)
            p: (profile[p] as List)
                .take(5)
                .map((e) => (e as num).toDouble())
                .toList(),
      };
      return jsonEncode(slim);
    } catch (_) {
      return profile.toString();
    }
  }
}
