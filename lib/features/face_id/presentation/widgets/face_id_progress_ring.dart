import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Apple Face ID setup ring — tick-segmented, glowing, smooth fill.
///
/// Visual elements (back-to-front):
///   1. Soft outer halo (only while actively scanning).
///   2. Faint track of unlit tick segments around the circle.
///   3. Lit tick segments that grow with [progress] (and individual ticks
///      pop in via a subtle scale animation as they activate).
///   4. Sweeping capture arc (only while scanning).
///   5. Center face-position dot (off when scan is complete).
///   6. Success checkmark on completion.
class FaceIdProgressRing extends StatefulWidget {
  const FaceIdProgressRing({
    super.key,
    required this.progress,
    required this.diameter,
    this.strokeWidth = 4,
    this.isCapturing = false,
    this.isComplete = false,
    this.isLocked = false,
    this.ringColor,
    this.faceDotOffset,
  });

  final double progress;
  final double diameter;
  final double strokeWidth;
  final bool isCapturing;
  final bool isComplete;
  final bool isLocked;
  final Color? ringColor;
  final Offset? faceDotOffset;

  @override
  State<FaceIdProgressRing> createState() => _FaceIdProgressRingState();
}

class _FaceIdProgressRingState extends State<FaceIdProgressRing>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _haloCtrl;
  late final AnimationController _completeCtrl;
  double _shown = 0;

  @override
  void initState() {
    super.initState();
    _shown = widget.progress;
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _completeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _syncAnimators();
  }

  @override
  void didUpdateWidget(covariant FaceIdProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimators();
  }

  void _syncAnimators() {
    if (widget.isCapturing && !widget.isComplete) {
      if (!_spinCtrl.isAnimating) _spinCtrl.repeat();
    } else {
      if (_spinCtrl.isAnimating) _spinCtrl.stop();
    }
    if (widget.isComplete && _completeCtrl.value < 1.0) {
      _completeCtrl.forward();
    } else if (!widget.isComplete && _completeCtrl.value > 0) {
      _completeCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _haloCtrl.dispose();
    _completeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.ringColor ??
        (widget.isComplete || widget.isLocked
            ? const Color(0xFF34C759)
            : Colors.white);

    return SizedBox(
      width: widget.diameter + 60,
      height: widget.diameter + 60,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: _shown, end: widget.progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        onEnd: () => _shown = widget.progress,
        builder: (context, animatedProgress, _) {
          return AnimatedBuilder(
            animation: Listenable.merge([_spinCtrl, _haloCtrl, _completeCtrl]),
            builder: (context, __) {
              return CustomPaint(
                painter: _FaceIdRingPainter(
                  progress: animatedProgress,
                  diameter: widget.diameter,
                  strokeWidth: widget.strokeWidth,
                  color: accent,
                  haloPhase: _haloCtrl.value,
                  spinPhase: _spinCtrl.value,
                  showHalo: widget.isCapturing && !widget.isComplete,
                  showSpinArc: widget.isCapturing && !widget.isComplete,
                  completePhase: _completeCtrl.value,
                  isComplete: widget.isComplete,
                  faceDotOffset: widget.isComplete ? null : widget.faceDotOffset,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FaceIdRingPainter extends CustomPainter {
  _FaceIdRingPainter({
    required this.progress,
    required this.diameter,
    required this.strokeWidth,
    required this.color,
    required this.haloPhase,
    required this.spinPhase,
    required this.showHalo,
    required this.showSpinArc,
    required this.completePhase,
    required this.isComplete,
    this.faceDotOffset,
  });

  final double progress;
  final double diameter;
  final double strokeWidth;
  final Color color;
  final double haloPhase;
  final double spinPhase;
  final bool showHalo;
  final bool showSpinArc;
  final double completePhase;
  final bool isComplete;
  final Offset? faceDotOffset;

  static const int _tickCount = 60;
  static const double _tickLength = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = diameter / 2;
    final tickInner = outerR - _tickLength;

    if (showHalo) {
      final haloR = outerR + 18 + haloPhase * 10;
      final haloPaint = Paint()
        ..color = color.withValues(alpha: 0.10 + (1 - haloPhase) * 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(center, haloR, haloPaint);
    }

    final activeUntil = (progress * _tickCount).clamp(0.0, _tickCount.toDouble());
    final boundary = activeUntil - activeUntil.floorToDouble();
    final fullyActive = activeUntil.floor();

    for (var i = 0; i < _tickCount; i++) {
      final angle = (i / _tickCount) * 2 * math.pi - math.pi / 2;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      final pStart = Offset(center.dx + dx * tickInner, center.dy + dy * tickInner);
      final pEnd = Offset(center.dx + dx * outerR, center.dy + dy * outerR);

      final isActive = i < fullyActive;
      final isEdge = i == fullyActive;
      final edgeStrength = isEdge ? boundary : 0.0;

      double alpha;
      double widthMul;
      if (isActive) {
        alpha = isComplete ? 0.95 : 0.92;
        widthMul = 1.0;
      } else if (isEdge) {
        alpha = 0.30 + 0.65 * edgeStrength;
        widthMul = 0.85 + 0.15 * edgeStrength;
      } else {
        alpha = 0.18;
        widthMul = 0.7;
      }

      final paint = Paint()
        ..color = (isActive || isEdge ? color : Colors.white)
            .withValues(alpha: alpha)
        ..strokeWidth = strokeWidth * widthMul
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pStart, pEnd, paint);

      if (isActive && !isComplete) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.30)
          ..strokeWidth = strokeWidth * 2.2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawLine(pStart, pEnd, glowPaint);
      }
    }

    if (showSpinArc && progress < 0.98) {
      final spinR = outerR - _tickLength / 2;
      final arcRect = Rect.fromCircle(center: center, radius: spinR);
      final arcPaint = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.7
        ..strokeCap = StrokeCap.round;
      final start = -math.pi / 2 + spinPhase * 2 * math.pi;
      canvas.drawArc(arcRect, start, math.pi / 3, false, arcPaint);
    }

    if (isComplete) {
      _drawCheck(canvas, center, outerR * 0.55, color, completePhase);
    } else {
      final dot = faceDotOffset;
      if (dot != null) {
        final dotCenter = Offset(
          center.dx + dot.dx * tickInner * 0.35,
          center.dy + dot.dy * tickInner * 0.35,
        );
        final dotGlow = Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(dotCenter, 9, dotGlow);
        canvas.drawCircle(
          dotCenter,
          4.5,
          Paint()..color = color.withValues(alpha: 0.95),
        );
      }
    }
  }

  void _drawCheck(Canvas canvas, Offset center, double size, Color color, double t) {
    final eased = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    final s = size * eased;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final p1 = Offset(center.dx - s * 0.45, center.dy + s * 0.05);
    final p2 = Offset(center.dx - s * 0.10, center.dy + s * 0.40);
    final p3 = Offset(center.dx + s * 0.55, center.dy - s * 0.35);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceIdRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.haloPhase != haloPhase ||
      old.spinPhase != spinPhase ||
      old.showHalo != showHalo ||
      old.showSpinArc != showSpinArc ||
      old.completePhase != completePhase ||
      old.isComplete != isComplete ||
      old.faceDotOffset != faceDotOffset;
}
