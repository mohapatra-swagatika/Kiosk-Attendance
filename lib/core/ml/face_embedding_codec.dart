import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:attendance_kiosk_app/core/ml/android_ml_tuning.dart';
import 'package:attendance_kiosk_app/core/ml/face_match_debug_log.dart';
import 'package:attendance_kiosk_app/core/ml/face_profile_poses.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Active runtime embedding mode (set at app start by `bootstrap()` based on
/// whether `mobile_face_net.tflite` was found in assets).
enum FaceEmbeddingMode {
  /// MobileFaceNet (or compatible) TFLite — 192-dim neural embeddings.
  tflite,

  /// ML Kit face contours — 216-dim geometric embeddings (fallback).
  contour,
}

/// Biometric face embedding with two backends:
///
/// * **tflite (v6)** — MobileFaceNet 192-dim embeddings, threshold 0.90 (90%+).
/// * **contour (v5)** — ML Kit contour 216-dim embeddings, threshold 0.94.
///
/// Mode is set once at startup. Profiles store the version they were
/// generated with; auto-purge removes profiles that don't match the
/// current mode so we never compare across embedding types.
class FaceEmbeddingCodec {
  FaceEmbeddingCodec._();

  static const int storageVersionContour = 5;
  // v7 = canonical InsightFace eye-aligned crop + deterministic photometric
  // normalization. Embeddings produced by older versions are incompatible.
  static const int storageVersionTflite = 7;

  static const double minVisibilityRatio = 0.15;
  static const double maxPitchAbs = 15;

  /// Cosine thresholds per backend.
  static const double matchThresholdContour = 0.94;
  static const double matchMarginMinContour = 0.025;

  /// Strict kiosk thresholds (MobileFaceNet, L2-normalized cosine = displayed %).
  ///
  /// `match` — accept only when similarity ≥ 90% (0.90).
  /// `matchLocked` — same bar while tracking the same person (no weak re-match).
  /// `lockMaintain` — locked id still visible — suppress unknown popups.
  /// `margin` — required gap over 2nd-best (anti-collision).
  /// `unknownPopupMinScore` — "No Employee Found" only when face is close but < 90%.
  /// Gallery match threshold (multi-template score vs enrolled identity set).
  static const double matchThresholdTflite = 0.84;

  /// Minimum match confidence shown in UI (sync with [matchThresholdTflite]).
  static const int minMatchConfidencePercent = 84;

  /// Clear winner only when score already meets threshold and gap is very large.
  static const double clearWinnerScoreTflite = matchThresholdTflite;
  static const double clearWinnerMarginTflite = 0.18;

  static const double matchThresholdTfliteLocked = 0.82;

  static const double lockMaintainThresholdTflite = 0.74;

  static const double enrolledRecognizedThresholdTflite = 0.70;

  /// Standard margin — block when two enrolled users score similarly.
  static const double matchMarginMinTflite = 0.08;
  static const double matchMarginMinTfliteLocked = 0.06;

  /// At least one enrolled template must match (glasses on/off, beard, lighting).
  static const double variationAnchorMinTflite = 0.76;

  /// 2nd-place score this high → treat as ambiguous unless margin is very large.
  static const double ambiguousPeerScoreTflite = 0.76;

  /// High-confidence match can use the standard margin; weaker scores need more gap.
  static const double highConfidenceMatchTflite = 0.90;
  static const double elevatedMatchMarginTflite = 0.10;

  /// Block enrolling when any template is too similar to another employee.
  static const double enrollmentDuplicateMaxMin = 0.82;

  /// Only show "No Employee Found" when face is clearly in the gallery
  /// distribution but below threshold (avoid scaring registered users with
  /// a slightly weak frame).
  static const double unknownPopupMinScore = 0.70;

  /// Below this score the face is clearly not enrolled — kiosk may reject in
  /// one frame (flow layer; matching thresholds unchanged).
  static const double clearlyUnknownMaxScore = 0.58;

  /// Best score below match threshold with this margin → instant "not found".
  static const double fastUnknownMarginMin = 0.09;

  /// Grey band 0.58–0.70: weak read of enrolled vs unknown — brief confirm only.
  static const double greyZoneTightScoreMax = 0.62;
  static const double greyZoneAmbiguousMarginMax = 0.07;
  static const int greyZoneUnknownStreakTight = 2;
  static const int greyZoneUnknownStreakAmbiguous = 3;

  /// Any accepted match opens the kiosk dialog instantly (matchProbe already
  /// applies threshold + margin + clear-winner checks).
  static const double instantMatchConfidence = matchThresholdTflite;

  /// True when cosine score meets the minimum displayed match confidence.
  static bool meetsMinMatchConfidence(double cosineScore) =>
      cosineScore >= matchThresholdTflite;

  /// How many rejected frames before showing "No Employee Found".
  ///
  /// Replaces the old grey-zone path that cleared the streak and waited forever.
  static int unknownConfirmFrames({
    required double bestScore,
    required double margin,
  }) {
    // Any rejected probe below match threshold → show "No Employee Found" quickly.
    if (bestScore < matchThresholdTflite) return 1;
    if (margin < matchMarginMinTflite) return 1;
    return 1;
  }

  /// Expected MobileFaceNet output size (v6 profiles).
  static const int neuralEmbeddingDim = 192;

  static FaceEmbeddingMode _mode = FaceEmbeddingMode.tflite;

  static void setMode(FaceEmbeddingMode mode) {
    _mode = mode;
    FaceMatchDebugLog.log(
      '[FaceEmbedder] mode=${mode == FaceEmbeddingMode.tflite ? "tflite (v6 storage)" : "contour (v5 fallback)"}',
    );
  }

  static FaceEmbeddingMode get mode => _mode;
  static int get storageVersion => storageVersionTflite;
  static double get matchThreshold =>
      _mode == FaceEmbeddingMode.tflite ? matchThresholdTflite : matchThresholdContour;

  /// Platform-aware kiosk match bar (Android NV21 is slightly lower; iOS unchanged).
  static double get effectiveMatchThreshold {
    if (Platform.isAndroid && _mode == FaceEmbeddingMode.tflite) {
      return AndroidMlTuning.kioskMatchThreshold;
    }
    return matchThreshold;
  }

  static double get effectiveMatchThresholdLocked {
    if (Platform.isAndroid && _mode == FaceEmbeddingMode.tflite) {
      return AndroidMlTuning.kioskMatchThresholdLocked;
    }
    return matchThresholdTfliteLocked;
  }

  static double get effectiveAnchorMin {
    if (Platform.isAndroid && _mode == FaceEmbeddingMode.tflite) {
      return AndroidMlTuning.kioskAnchorMin;
    }
    return variationAnchorMinTflite;
  }

  /// UI / confirm streak (kiosk scan session).
  static double get effectiveInstantMatchConfidence => effectiveMatchThreshold;
  static double get matchMarginMin =>
      _mode == FaceEmbeddingMode.tflite ? matchMarginMinTflite : matchMarginMinContour;

  /// Sampling counts per contour (fixed so vectors are comparable).
  static const Map<FaceContourType, int> _samplePoints = {
    FaceContourType.face: 24,
    FaceContourType.leftEyebrowTop: 5,
    FaceContourType.leftEyebrowBottom: 5,
    FaceContourType.rightEyebrowTop: 5,
    FaceContourType.rightEyebrowBottom: 5,
    FaceContourType.leftEye: 12,
    FaceContourType.rightEye: 12,
    FaceContourType.upperLipTop: 8,
    FaceContourType.upperLipBottom: 8,
    FaceContourType.lowerLipTop: 8,
    FaceContourType.lowerLipBottom: 8,
    FaceContourType.noseBridge: 4,
    FaceContourType.noseBottom: 4,
  };

  static int get expectedVectorLength {
    var total = 0;
    for (final n in _samplePoints.values) {
      total += n;
    }
    return total * 2;
  }

  /// Produces an aligned contour-based identity vector or null if requirements unmet.
  static List<double>? identityFromFace(
    Face face, {
    required int imageWidth,
    required int imageHeight,
  }) {
    final box = face.boundingBox;
    final visibility = (box.width * box.height) / (imageWidth * imageHeight);
    if (visibility < minVisibilityRatio) return null;

    final pitch = face.headEulerAngleX ?? 0;
    if (pitch.abs() > maxPitchAbs) return null;

    final leLm = face.landmarks[FaceLandmarkType.leftEye];
    final reLm = face.landmarks[FaceLandmarkType.rightEye];
    if (leLm == null || reLm == null) return null;

    final le = leLm.position;
    final re = reLm.position;

    final dxEye = (re.x - le.x).toDouble();
    final dyEye = (re.y - le.y).toDouble();
    final eyeDist = math.sqrt(dxEye * dxEye + dyEye * dyEye);
    if (eyeDist < 32) return null;

    final cx = (le.x + re.x) / 2.0;
    final cy = (le.y + re.y) / 2.0;
    final angle = math.atan2(dyEye, dxEye);
    final cosA = math.cos(-angle);
    final sinA = math.sin(-angle);

    final points = <double>[];

    void addAligned(num px, num py) {
      final dx = px - cx;
      final dy = py - cy;
      final rx = (dx * cosA - dy * sinA) / eyeDist;
      final ry = (dx * sinA + dy * cosA) / eyeDist;
      points.add(rx);
      points.add(ry);
    }

    for (final entry in _samplePoints.entries) {
      final contour = face.contours[entry.key];
      if (contour == null || contour.points.isEmpty) {
        return null;
      }
      final sampled = _evenSample(contour.points, entry.value);
      for (final p in sampled) {
        addAligned(p.x, p.y);
      }
    }

    if (points.length != expectedVectorLength) return null;

    return _l2Normalize(points);
  }

  static List<Point<int>> _evenSample(List<Point<int>> src, int n) {
    if (n <= 0) return const [];
    if (src.length == n) return src;
    if (src.length < n) {
      return [
        ...src,
        for (var i = 0; i < n - src.length; i++) src.last,
      ];
    }
    final out = <Point<int>>[];
    for (var i = 0; i < n; i++) {
      final idx = (i * (src.length - 1) / (n - 1)).round();
      out.add(src[idx]);
    }
    return out;
  }

  static List<double> combinePoseVectors(List<List<double>> poses) {
    if (poses.isEmpty) return const [];
    final length = poses.first.length;
    final acc = List<double>.filled(length, 0);
    for (final p in poses) {
      if (p.length != length) continue;
      for (var i = 0; i < length; i++) {
        acc[i] += p[i];
      }
    }
    for (var i = 0; i < length; i++) {
      acc[i] /= poses.length;
    }
    return _l2Normalize(acc);
  }

  /// Drops outlier pose vectors (bad frames) before averaging — improves gallery quality.
  static List<double> combinePoseVectorsRobust(
    List<List<double>> poses, {
    double minSimilarityToCentroid = 0.55,
  }) {
    if (poses.isEmpty) return const [];
    if (poses.length == 1) return _l2Normalize(List<double>.from(poses.first));
    final centroid = combinePoseVectors(poses);
    if (centroid.isEmpty) return const [];

    final kept = <List<double>>[];
    for (final p in poses) {
      if (p.length != centroid.length) continue;
      if (cosineSimilarity(p, centroid) >= minSimilarityToCentroid) {
        kept.add(p);
      }
    }
    if (kept.isEmpty) return centroid;
    return combinePoseVectors(kept);
  }

  /// Temporal fusion of recent live probes (same face track) for stabler matching.
  static List<double>? fuseProbeEmbeddings(List<List<double>> probes) {
    if (probes.isEmpty) return null;
    if (probes.length == 1) return _l2Normalize(List<double>.from(probes.first));
    return combinePoseVectorsRobust(probes, minSimilarityToCentroid: 0.58);
  }

  /// Keeps enrollment captures that differ (glasses, angle, lighting) for later matching.
  static List<List<double>> pickDiverseEnrollmentTemplates(
    List<List<double>> candidates, {
    int maxCount = 14,
    double minNovelty = 0.05,
  }) {
    if (candidates.isEmpty) return const [];
    final normed = <List<double>>[];
    for (final c in candidates) {
      if (c.isEmpty) continue;
      final n = _l2Normalize(List<double>.from(c));
      var dup = false;
      for (final existing in normed) {
        if (cosineSimilarity(n, existing) > 0.985) {
          dup = true;
          break;
        }
      }
      if (!dup) normed.add(n);
    }
    if (normed.isEmpty) return const [];

    final picked = <List<double>>[normed.first];
    while (picked.length < maxCount && picked.length < normed.length) {
      List<double>? best;
      var bestNovelty = -1.0;
      for (final c in normed) {
        var maxSim = 0.0;
        for (final p in picked) {
          maxSim = math.max(maxSim, cosineSimilarity(c, p));
        }
        final novelty = 1.0 - maxSim;
        if (novelty > bestNovelty) {
          bestNovelty = novelty;
          best = c;
        }
      }
      if (best == null || bestNovelty < minNovelty) break;
      var already = false;
      for (final p in picked) {
        if (cosineSimilarity(best, p) > 0.985) {
          already = true;
          break;
        }
      }
      if (already) break;
      picked.add(best);
    }
    return picked;
  }

  static List<List<double>> _allStoredEmbeddings(Map<String, dynamic> profile) {
    final out = <List<double>>[];
    for (final key in FaceProfilePoses.matchKeys) {
      final v = _poseVector(profile, key);
      if (v != null) out.add(v);
    }
    final bank = profile[FaceProfilePoses.templatesKey];
    if (bank is List) {
      for (final item in bank) {
        if (item is List && item.isNotEmpty) {
          out.add(item.map((e) => (e as num).toDouble()).toList());
        }
      }
    }
    return out;
  }

  static List<double> _templateSimilarities(
    List<double> probe,
    Map<String, dynamic> profile,
  ) {
    final sims = <double>[];
    for (final emb in _allStoredEmbeddings(profile)) {
      if (emb.length != probe.length) continue;
      sims.add(cosineSimilarity(probe, emb));
    }
    return sims;
  }

  /// Best single-template match for this employee (appearance-tolerant anchor).
  static double identityAnchorScore(List<double> probe, Map<String, dynamic> profile) {
    final sims = _templateSimilarities(probe, profile);
    if (sims.isEmpty) return 0.0;
    return sims.reduce(math.max);
  }

  /// Reject only clearly bad enrollment frames; allow glasses/beard/lighting drift.
  static bool isEnrollmentSampleConsistent({
    required List<double> candidate,
    required List<List<double>> existing,
    double? minSimilarityToAny,
    double? rejectBelow,
  }) {
    if (existing.isEmpty) return true;
    minSimilarityToAny ??=
        Platform.isAndroid ? 0.36 : 0.48;
    rejectBelow ??= Platform.isAndroid ? 0.28 : 0.38;
    if (candidate.length != existing.first.length) return false;
    var maxToAny = 0.0;
    for (final e in existing) {
      maxToAny = math.max(maxToAny, cosineSimilarity(candidate, e));
    }
    if (maxToAny < rejectBelow) return false;
    if (maxToAny >= minSimilarityToAny) return true;
    final ref = combinePoseVectors(existing);
    return cosineSimilarity(candidate, ref) >= rejectBelow;
  }

  /// L2-normalize a vector (used for probe temporal smoothing).
  static List<double> l2Normalize(List<double> v) {
    return _l2Normalize(v);
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

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }

  static double meanAbsDiff(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return double.infinity;
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]).abs();
    }
    return sum / a.length;
  }

  static List<double>? _poseVector(Map<String, dynamic> profile, String pose) {
    final raw = profile[pose];
    if (raw is! List) return null;
    return raw.map((e) => (e as num).toDouble()).toList();
  }

  /// Cosine vs stored frontal template (debug / legacy).
  static double frontalTemplateScore(List<double> probe, Map<String, dynamic> profile) {
    final straight = _poseVector(profile, FaceProfilePoses.straight);
    if (straight == null || straight.length != probe.length) return 0.0;
    return cosineSimilarity(probe, straight);
  }

  static double requiredMatchMargin(double bestScore) {
    if (_mode != FaceEmbeddingMode.tflite) return matchMarginMinContour;
    if (bestScore >= highConfidenceMatchTflite) return matchMarginMinTflite;
    return math.max(matchMarginMinTflite, elevatedMatchMarginTflite);
  }

  /// Gallery score — TFLite uses frontal identity; contour keeps multi-pose + bonuses.
  static double scoreRecognitionProbe(
    List<double> probe,
    Map<String, dynamic> profile, {
    double? probeYaw,
    double? probePitch,
  }) {
    if (_mode == FaceEmbeddingMode.tflite) {
      return _scoreTfliteIdentityProbe(probe, profile);
    }
    return _scoreContourProbe(probe, profile, probeYaw: probeYaw, probePitch: probePitch);
  }

  /// MobileFaceNet: score vs all templates for this employee; top-2 blend tolerates
  /// glasses/beard/lighting while inter-employee margin blocks lookalikes.
  static double _scoreTfliteIdentityProbe(
    List<double> probe,
    Map<String, dynamic> profile,
  ) {
    final sims = _templateSimilarities(probe, profile);
    if (sims.isEmpty) return 0.0;
    sims.sort();
    final best = sims.last;
    final second = sims.length >= 2 ? sims[sims.length - 2] : best;
    return (best * 0.55 + second * 0.45).clamp(0.0, 1.0);
  }

  static double _scoreContourProbe(
    List<double> probe,
    Map<String, dynamic> profile, {
    double? probeYaw,
    double? probePitch,
  }) {
    var best = 0.0;

    for (final key in FaceProfilePoses.matchKeys) {
      final v = _poseVector(profile, key);
      if (v == null || v.length != probe.length) continue;
      final sim = cosineSimilarity(probe, v);
      best = math.max(best, sim + _poseAffinityBonus(key, sim, probeYaw, probePitch));
    }

    final bank = profile[FaceProfilePoses.templatesKey];
    if (bank is List) {
      final bankSims = <double>[];
      for (final item in bank) {
        if (item is! List || item.length != probe.length) continue;
        final v = item.map((e) => (e as num).toDouble()).toList();
        bankSims.add(cosineSimilarity(probe, v));
      }
      if (bankSims.isNotEmpty) {
        bankSims.sort();
        final top = bankSims.last;
        if (bankSims.length >= 2) {
          final top2Mean = (bankSims.last + bankSims[bankSims.length - 2]) / 2;
          best = math.max(best, top * 0.65 + top2Mean * 0.35);
        } else {
          best = math.max(best, top);
        }
      }
    }

    return best.clamp(0.0, 1.0);
  }

  /// Small bonus when live head pose aligns with a stored pose template.
  static double _poseAffinityBonus(
    String poseKey,
    double similarity,
    double? yaw,
    double? pitch,
  ) {
    if (similarity < 0.35) return 0;
    var bonus = 0.0;
    if (yaw != null) {
      if (poseKey == FaceProfilePoses.left && yaw < -10) bonus = 0.04;
      if (poseKey == FaceProfilePoses.right && yaw > 10) bonus = 0.04;
      if (poseKey == FaceProfilePoses.straight && yaw.abs() < 12) bonus = 0.03;
    }
    if (pitch != null) {
      if (poseKey == FaceProfilePoses.up && pitch < -10) bonus = math.max(bonus, 0.04);
      if (poseKey == FaceProfilePoses.down && pitch > 10) bonus = math.max(bonus, 0.04);
    }
    if (poseKey == FaceProfilePoses.combined) bonus = math.max(bonus, 0.02);
    return bonus;
  }

  static FaceMatchOutcome matchProbe({
    required List<double> probe,
    required Map<String, Map<String, dynamic>> gallery,
    String? excludeEmployeeId,
    String? lockedEmployeeId,
    double? probeYaw,
    double? probePitch,
  }) {
    final scores = <String, double>{};
    final skipped = <String>[];
    for (final entry in gallery.entries) {
      if (entry.key == excludeEmployeeId) continue;
      final straight = _poseVector(entry.value, FaceProfilePoses.straight);
      if (straight == null || straight.length != probe.length) {
        skipped.add(entry.key);
        continue;
      }
      scores[entry.key] = scoreRecognitionProbe(
        probe,
        entry.value,
        probeYaw: probeYaw,
        probePitch: probePitch,
      );
    }

    if (skipped.isNotEmpty) {
      FaceMatchDebugLog.log(
        'matchProbe: skipped (dim mismatch, re-enroll with v$storageVersion): ${skipped.join(', ')}',
      );
    }

    if (scores.isEmpty) {
      return FaceMatchOutcome(
        rejected: true,
        reason: skipped.isNotEmpty
            ? 'Stored faces use an older format — admin reset and re-enroll.'
            : 'No registered faces',
      );
    }

    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final best = sorted.first;
    final second = sorted.length > 1 ? sorted[1].value : 0.0;
    final margin = best.value - second;
    final bestProfile = gallery[best.key]!;
    final bestAnchor = identityAnchorScore(probe, bestProfile);
    final bestFrontal = frontalTemplateScore(probe, bestProfile);

    final isTfliteMode = _mode == FaceEmbeddingMode.tflite;
    final reqMargin = requiredMatchMargin(best.value);
    final matchThr = effectiveMatchThreshold;
    final anchorMin = effectiveAnchorMin;
    final wouldPassThreshold = best.value >= matchThr;
    final wouldPassMargin = margin >= reqMargin;
    final wouldPassAnchor = !isTfliteMode || bestAnchor >= anchorMin;
    final wouldPassClearWinner = isTfliteMode &&
        best.value >= clearWinnerScoreTflite &&
        margin >= clearWinnerMarginTflite;
    FaceMatchDebugLog.log(
      'matchProbe best=${best.key} ${best.value.toStringAsFixed(4)} '
      'anchor=${bestAnchor.toStringAsFixed(4)} frontal=${bestFrontal.toStringAsFixed(4)} '
      '2nd=${second.toStringAsFixed(4)} margin=${margin.toStringAsFixed(4)} '
      'reqMargin=${reqMargin.toStringAsFixed(2)}'
      '${lockedEmployeeId != null ? ' lock=$lockedEmployeeId' : ''} '
      'gates[thr=$wouldPassThreshold mar=$wouldPassMargin '
      'anchor=$wouldPassAnchor clr=$wouldPassClearWinner]',
    );

    // Hysteresis: keep tracking a recently matched employee at a lower bar.
    if (lockedEmployeeId != null && scores.containsKey(lockedEmployeeId)) {
      final lockedScore = scores[lockedEmployeeId]!;
      final others = scores.entries
          .where((e) => e.key != lockedEmployeeId)
          .map((e) => e.value);
      final secondOther = others.isEmpty ? 0.0 : others.reduce(math.max);
      final lockedMargin = lockedScore - secondOther;
      if (lockedScore >= effectiveMatchThresholdLocked &&
          lockedMargin >= matchMarginMinTfliteLocked) {
        final lockProfile = gallery[lockedEmployeeId]!;
        final lockAnchor = identityAnchorScore(probe, lockProfile);
        final anchorOk =
            !isTfliteMode || lockAnchor >= effectiveAnchorMin - 0.02;
        if (anchorOk) {
          return FaceMatchOutcome(
            employeeId: lockedEmployeeId,
            confidence: lockedScore,
            margin: lockedMargin,
            bestEmployeeId: lockedEmployeeId,
            bestScore: lockedScore,
          );
        }
      }
    }

    final clearWinner = wouldPassClearWinner;

    if (isTfliteMode && bestAnchor < anchorMin) {
      return FaceMatchOutcome(
        rejected: true,
        reason: 'Unknown face',
        bestEmployeeId: best.key,
        bestScore: best.value,
        margin: margin,
      );
    }

    if (isTfliteMode &&
        second >= ambiguousPeerScoreTflite &&
        margin < reqMargin) {
      return FaceMatchOutcome(
        rejected: true,
        reason: 'Ambiguous match — face too similar to multiple users',
        bestEmployeeId: best.key,
        bestScore: best.value,
        margin: margin,
      );
    }

    if (best.value < matchThr && !clearWinner) {
      return FaceMatchOutcome(
        rejected: true,
        reason: 'Unknown face',
        bestEmployeeId: best.key,
        bestScore: best.value,
        margin: margin,
      );
    }
    if (margin < reqMargin && !clearWinner) {
      return FaceMatchOutcome(
        rejected: true,
        reason: 'Ambiguous match — face too similar to multiple users',
        bestEmployeeId: best.key,
        bestScore: best.value,
        margin: margin,
      );
    }

    return FaceMatchOutcome(
      employeeId: best.key,
      confidence: best.value,
      margin: margin,
      bestEmployeeId: best.key,
      bestScore: best.value,
    );
  }

  /// Rejects enrollment when the new frontal template matches another employee.
  static DuplicateCheckResult checkDuplicateProfile({
    required Map<String, dynamic> newProfile,
    required Map<String, Map<String, dynamic>> gallery,
    required String registeringEmployeeId,
  }) {
    FaceMatchDebugLog.clear();
    FaceMatchDebugLog.log('=== DUPLICATE CHECK: registering=$registeringEmployeeId ===');

    final newTemplates = _allStoredEmbeddings(newProfile);
    if (newTemplates.isEmpty) {
      return DuplicateCheckResult(
        isDuplicate: false,
        debugLog: 'No templates in new profile.',
      );
    }

    var bestSim = 0.0;
    String? matchedId;
    for (final entry in gallery.entries) {
      if (entry.key == registeringEmployeeId) continue;
      final stored = _allStoredEmbeddings(entry.value);
      var entryMax = 0.0;
      for (final n in newTemplates) {
        for (final s in stored) {
          if (n.length != s.length) continue;
          final sim = cosineSimilarity(n, s);
          entryMax = math.max(entryMax, sim);
          if (sim > bestSim) {
            bestSim = sim;
            matchedId = entry.key;
          }
        }
      }
      FaceMatchDebugLog.log(
        '  max vs ${entry.key}: cosine=${entryMax.toStringAsFixed(4)}',
      );
    }

    final isDuplicate = bestSim >= enrollmentDuplicateMaxMin;
    if (isDuplicate) {
      FaceMatchDebugLog.log(
        'DUPLICATE: ${matchedId ?? "?"} max=${bestSim.toStringAsFixed(4)} '
        '≥ $enrollmentDuplicateMaxMin',
      );
    }
    return DuplicateCheckResult(
      isDuplicate: isDuplicate,
      matchedEmployeeId: isDuplicate ? matchedId : null,
      straightScore: bestSim,
      debugLog: FaceMatchDebugLog.lastReportAsText(),
    );
  }
}

class DuplicateCheckResult {
  const DuplicateCheckResult({
    required this.isDuplicate,
    this.matchedEmployeeId,
    this.straightScore = 0,
    this.minPoseScore = 0,
    this.maxMeanAbsDiff = 0,
    this.debugLog,
  });

  final bool isDuplicate;
  final String? matchedEmployeeId;
  final double straightScore;
  final double minPoseScore;
  final double maxMeanAbsDiff;
  final String? debugLog;
}

class FaceMatchOutcome {
  const FaceMatchOutcome({
    this.employeeId,
    this.confidence = 0,
    this.margin = 0,
    this.rejected = false,
    this.reason,
    this.bestScore = 0,
    this.bestEmployeeId,
  });

  final String? employeeId;
  final double confidence;
  final double margin;
  final bool rejected;
  final String? reason;
  final double bestScore;

  /// Top gallery candidate even when [rejected] (for lock / suppress-unknown logic).
  final String? bestEmployeeId;
}
