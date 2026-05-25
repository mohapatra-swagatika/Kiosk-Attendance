import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';

/// Cooldown, face tracking, and throttling for instant kiosk unlock scanning.
class KioskScanSession extends Notifier<KioskScanState> {
  /// Short pause before re-opening the same employee dialog.
  static const Duration employeeCooldown = Duration(seconds: 2);

  static const Duration unknownPopupCooldown = Duration(seconds: 6);

  static const Duration faceLockDuration = Duration(seconds: 35);
  static const Duration postMatchGrace = Duration(seconds: 6);

  /// ~30 FPS on iOS; slightly faster cadence on Android for fluid tracking.
  static Duration get frameThrottle => Platform.isAndroid
      ? const Duration(milliseconds: 26)
      : const Duration(milliseconds: 33);

  /// Min gap between TFLite embeds (reuse cached vector between gaps).
  static Duration get embedThrottle => Platform.isAndroid
      ? const Duration(milliseconds: 40)
      : const Duration(milliseconds: 48);

  /// Default unknown reads before popup.
  static const int unknownStreakRequired = 1;

  /// After a match, still require only 1–2 reads for unknown (not 12).
  static const int unknownStreakDuringGrace = 1;
  static const int noFaceFramesToResetUnknown = 4;

  /// Consecutive frames with the same employee before opening the dialog.
  static const int matchConfirmFramesDefault = 2;
  static const int matchConfirmFramesBorderline = 3;
  static const double borderlineMatchConfidence = 0.88;

  /// Minimum separation from 2nd-best (blocks lookalike false accepts).
  static const double minConfirmMargin = 0.08;

  /// Reject confirm streak when head pose jumps between frames.
  static const double maxConfirmYawDelta = 12;
  static const double maxConfirmPitchDelta = 10;

  /// EMA smoothing for match confidence (reduces one-frame false accepts).
  static const double _matchConfidenceEmaAlpha = 0.5;
  double? _matchConfidenceEma;
  double? _lastConfirmYaw;
  double? _lastConfirmPitch;

  @override
  KioskScanState build() =>
      KioskScanState(throttleUntil: DateTime.fromMillisecondsSinceEpoch(0));

  bool canProcessFrame() {
    if (state.dialogOpen || state.scanPaused) return false;
    return DateTime.now().isAfter(state.throttleUntil);
  }

  void markFrameProcessed() {
    state = state.copyWith(throttleUntil: DateTime.now().add(frameThrottle));
  }

  bool canRunEmbed() {
    final until = state.embedThrottleUntil;
    if (until == null) return true;
    return DateTime.now().isAfter(until);
  }

  void markEmbedProcessed() {
    state = state.copyWith(
      embedThrottleUntil: DateTime.now().add(embedThrottle),
    );
  }

  bool get liveGateSatisfied => state.liveGatePassed;

  void markLiveGatePassed() {
    if (state.liveGatePassed) return;
    state = state.copyWith(liveGatePassed: true);
  }

  bool isEmployeeOnCooldown(String employeeId) {
    final until = state.cooldowns[employeeId];
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  bool get isUnknownPopupOnCooldown {
    final until = state.unknownPopupUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  String? get lockedEmployeeId {
    final id = state.lockedEmployeeId;
    final until = state.lockUntil;
    if (id == null || until == null) return null;
    if (DateTime.now().isAfter(until)) return null;
    return id;
  }

  void bindFaceTrack(int? trackingId) {
    if (trackingId == null) return;
    state = state.copyWith(activeTrackingId: trackingId);
  }

  bool registerMatchCandidate(
    String employeeId, {
    required double confidence,
    required double margin,
    double? yaw,
    double? pitch,
  }) {
    if (confidence < FaceEmbeddingCodec.instantMatchConfidence) {
      _resetMatchConfirmState();
      return false;
    }
    if (margin < minConfirmMargin && confidence < 0.92) {
      _resetMatchConfirmState();
      return false;
    }

    final pending = state.pendingEmployeeId;
    if (pending == employeeId && yaw != null && _lastConfirmYaw != null) {
      final dy = (yaw - _lastConfirmYaw!).abs();
      final dp = pitch != null && _lastConfirmPitch != null
          ? (pitch - _lastConfirmPitch!).abs()
          : 0.0;
      if (dy > maxConfirmYawDelta || dp > maxConfirmPitchDelta) {
        _resetMatchConfirmState();
        _lastConfirmYaw = yaw;
        _lastConfirmPitch = pitch;
        return false;
      }
    }
    _lastConfirmYaw = yaw;
    _lastConfirmPitch = pitch;

    _matchConfidenceEma = _matchConfidenceEma == null
        ? confidence
        : _matchConfidenceEma! +
            (confidence - _matchConfidenceEma!) * _matchConfidenceEmaAlpha;
    final smoothed = _matchConfidenceEma!;

    final streak = pending == employeeId ? state.matchConfirmStreak + 1 : 1;
    state = state.copyWith(
      pendingEmployeeId: employeeId,
      matchConfirmStreak: streak,
      unknownStreak: 0,
      noFaceStreak: 0,
    );

    final framesNeeded = smoothed >= borderlineMatchConfidence
        ? matchConfirmFramesDefault
        : matchConfirmFramesBorderline;
    final confirmed = streak >= framesNeeded &&
        smoothed >= FaceEmbeddingCodec.instantMatchConfidence &&
        confidence >= FaceEmbeddingCodec.instantMatchConfidence;
    if (confirmed) {
      _activateLock(employeeId);
    }
    return confirmed;
  }

  void _resetMatchSmoothing() {
    _matchConfidenceEma = null;
    _lastConfirmYaw = null;
    _lastConfirmPitch = null;
  }

  void _resetMatchConfirmState() {
    _resetMatchSmoothing();
    state = state.copyWith(
      pendingEmployeeId: null,
      matchConfirmStreak: 0,
    );
  }

  void refreshFaceLock(String employeeId) {
    if (lockedEmployeeId == employeeId) {
      _activateLock(employeeId);
    }
    state = state.copyWith(unknownStreak: 0, noFaceStreak: 0);
  }

  void _activateLock(String employeeId) {
    final now = DateTime.now();
    state = state.copyWith(
      lockedEmployeeId: employeeId,
      lockUntil: now.add(faceLockDuration),
      postMatchGraceUntil: now.add(postMatchGrace),
      lastMatchedEmployeeId: employeeId,
    );
  }

  int requiredUnknownStreakForScore(double bestScore) {
    if (bestScore < FaceEmbeddingCodec.clearlyUnknownMaxScore) return 1;
    if (bestScore >= FaceEmbeddingCodec.unknownPopupMinScore) return 1;
    return _requiredUnknownStreak();
  }

  bool registerBiometricUnknown({int? requiredStreak}) {
    final need = requiredStreak ?? _requiredUnknownStreak();
    final streak = state.unknownStreak + 1;
    state = state.copyWith(
      pendingEmployeeId: null,
      matchConfirmStreak: 0,
      unknownStreak: streak,
      // Re-embed on the very next frame while confirming unknown (no 40ms wait).
      embedThrottleUntil: streak < need
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : state.embedThrottleUntil,
    );
    return streak >= need && !isUnknownPopupOnCooldown;
  }

  int _requiredUnknownStreak() {
    final grace = state.postMatchGraceUntil;
    if (grace != null && DateTime.now().isBefore(grace)) {
      return unknownStreakDuringGrace;
    }
    return unknownStreakRequired;
  }

  void clearUnknownStreak() {
    if (state.unknownStreak == 0 &&
        state.matchConfirmStreak == 0 &&
        state.pendingEmployeeId == null) {
      return;
    }
    _resetMatchSmoothing();
    state = state.copyWith(
      unknownStreak: 0,
      matchConfirmStreak: 0,
      pendingEmployeeId: null,
    );
  }

  void onNoReliableFace() {
    _resetMatchSmoothing();
    state = state.copyWith(
      noFaceStreak: state.noFaceStreak + 1,
      matchConfirmStreak: 0,
      pendingEmployeeId: null,
    );
    // Keep unknownStreak — brief face-loss during movement must not cancel "No Employee Found".
  }

  void onFacePresent() {
    if (state.noFaceStreak == 0) return;
    state = state.copyWith(noFaceStreak: 0);
  }

  bool shouldSuppressUnknown({
    required String? bestEmployeeId,
    required double bestScore,
  }) {
    // Only suppress for an actively tracked (locked) employee — not for a loose 0.70
    // gallery read that would block "No Employee Found" for unregistered faces.
    final lockId = lockedEmployeeId;
    if (lockId != null &&
        bestEmployeeId == lockId &&
        bestScore >= FaceEmbeddingCodec.lockMaintainThresholdTflite) {
      return true;
    }

    final grace = state.postMatchGraceUntil;
    if (grace != null && DateTime.now().isBefore(grace)) {
      final last = state.lastMatchedEmployeeId;
      if (last != null &&
          bestEmployeeId == last &&
          bestScore >= FaceEmbeddingCodec.lockMaintainThresholdTflite) {
        return true;
      }
    }

    return false;
  }

  void onDialogOpening(String employeeId) {
    _activateLock(employeeId);
    state = state.copyWith(
      dialogOpen: true,
      scanPaused: true,
      pendingEmployeeId: null,
      matchConfirmStreak: 0,
      unknownStreak: 0,
      noFaceStreak: 0,
    );
  }

  void onUnknownDialogOpening() {
    state = state.copyWith(
      dialogOpen: true,
      scanPaused: true,
      unknownStreak: 0,
      matchConfirmStreak: 0,
    );
  }

  void onDialogClosed({bool matched = true}) {
    final id = state.lastMatchedEmployeeId;
    final cooldowns = Map<String, DateTime>.from(state.cooldowns);
    if (matched && id != null) {
      cooldowns[id] = DateTime.now().add(employeeCooldown);
      _activateLock(id);
    }
    _resetMatchSmoothing();
    state = state.copyWith(
      dialogOpen: false,
      scanPaused: false,
      cooldowns: cooldowns,
      pendingEmployeeId: null,
      matchConfirmStreak: 0,
      unknownStreak: 0,
      noFaceStreak: 0,
      unknownPopupUntil: matched
          ? state.unknownPopupUntil
          : DateTime.now().add(unknownPopupCooldown),
    );
  }

  /// Clears tracking caches; keeps live-gate + lock for fast re-scan.
  void softResetAfterDialog() {
    _resetMatchSmoothing();
    state = state.copyWith(
      pendingEmployeeId: null,
      matchConfirmStreak: 0,
      unknownStreak: 0,
      noFaceStreak: 0,
    );
  }

  void fullReset() {
    _resetMatchSmoothing();
    state = KioskScanState(
      throttleUntil: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class KioskScanState {
  const KioskScanState({
    this.dialogOpen = false,
    this.scanPaused = false,
    this.lastMatchedEmployeeId,
    this.cooldowns = const {},
    required this.throttleUntil,
    this.pendingEmployeeId,
    this.unknownStreak = 0,
    this.unknownPopupUntil,
    this.lockedEmployeeId,
    this.lockUntil,
    this.postMatchGraceUntil,
    this.noFaceStreak = 0,
    this.matchConfirmStreak = 0,
    this.activeTrackingId,
    this.liveGatePassed = false,
    this.embedThrottleUntil,
  });

  final bool dialogOpen;
  final bool scanPaused;
  final String? lastMatchedEmployeeId;
  final Map<String, DateTime> cooldowns;
  final DateTime throttleUntil;
  final String? pendingEmployeeId;
  final int unknownStreak;
  final DateTime? unknownPopupUntil;
  final String? lockedEmployeeId;
  final DateTime? lockUntil;
  final DateTime? postMatchGraceUntil;
  final int noFaceStreak;
  final int matchConfirmStreak;
  final int? activeTrackingId;
  final bool liveGatePassed;
  final DateTime? embedThrottleUntil;

  KioskScanState copyWith({
    bool? dialogOpen,
    bool? scanPaused,
    String? lastMatchedEmployeeId,
    Map<String, DateTime>? cooldowns,
    DateTime? throttleUntil,
    Object? pendingEmployeeId = _kSentinel,
    int? unknownStreak,
    Object? unknownPopupUntil = _kSentinel,
    Object? lockedEmployeeId = _kSentinel,
    Object? lockUntil = _kSentinel,
    Object? postMatchGraceUntil = _kSentinel,
    int? noFaceStreak,
    int? matchConfirmStreak,
    Object? activeTrackingId = _kSentinel,
    bool? liveGatePassed,
    Object? embedThrottleUntil = _kSentinel,
  }) {
    return KioskScanState(
      dialogOpen: dialogOpen ?? this.dialogOpen,
      scanPaused: scanPaused ?? this.scanPaused,
      lastMatchedEmployeeId: lastMatchedEmployeeId ?? this.lastMatchedEmployeeId,
      cooldowns: cooldowns ?? this.cooldowns,
      throttleUntil: throttleUntil ?? this.throttleUntil,
      pendingEmployeeId: identical(pendingEmployeeId, _kSentinel)
          ? this.pendingEmployeeId
          : pendingEmployeeId as String?,
      unknownStreak: unknownStreak ?? this.unknownStreak,
      unknownPopupUntil: identical(unknownPopupUntil, _kSentinel)
          ? this.unknownPopupUntil
          : unknownPopupUntil as DateTime?,
      lockedEmployeeId: identical(lockedEmployeeId, _kSentinel)
          ? this.lockedEmployeeId
          : lockedEmployeeId as String?,
      lockUntil:
          identical(lockUntil, _kSentinel) ? this.lockUntil : lockUntil as DateTime?,
      postMatchGraceUntil: identical(postMatchGraceUntil, _kSentinel)
          ? this.postMatchGraceUntil
          : postMatchGraceUntil as DateTime?,
      noFaceStreak: noFaceStreak ?? this.noFaceStreak,
      matchConfirmStreak: matchConfirmStreak ?? this.matchConfirmStreak,
      activeTrackingId: identical(activeTrackingId, _kSentinel)
          ? this.activeTrackingId
          : activeTrackingId as int?,
      liveGatePassed: liveGatePassed ?? this.liveGatePassed,
      embedThrottleUntil: identical(embedThrottleUntil, _kSentinel)
          ? this.embedThrottleUntil
          : embedThrottleUntil as DateTime?,
    );
  }
}

const _kSentinel = Object();

final kioskScanSessionProvider =
    NotifierProvider<KioskScanSession, KioskScanState>(KioskScanSession.new);
