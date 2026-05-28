import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/features/face_id/presentation/widgets/face_id_progress_ring.dart';

enum FaceIdArrowDirection { left, right, up, down }

/// Premium Face ID overlay used by enrollment and recognition.
///
/// Renders, in order: cinematic darken + radial vignette, circular "portal"
/// cutout so the camera shows through, the segmented progress ring, and
/// soft glass headers/footers for instructions.
class FaceIdScannerOverlay extends StatelessWidget {
  const FaceIdScannerOverlay({
    super.key,
    required this.ringProgress,
    required this.headline,
    required this.guidance,
    this.subtitle,
    this.detail,
    this.diameter = 0,
    this.isCapturing = false,
    this.isComplete = false,
    this.isLocked = false,
    this.faceDotOffset,
    this.arrowDirection,
    this.accentColor,
    this.showHeader = true,
  });

  final double ringProgress;
  final String headline;
  final String guidance;
  final String? subtitle;
  final String? detail;
  final double diameter;
  final bool isCapturing;
  final bool isComplete;
  final bool isLocked;
  final Offset? faceDotOffset;
  final FaceIdArrowDirection? arrowDirection;
  final Color? accentColor;
  final bool showHeader;

  /// Face ID–style ring size: large on phones, scales on tablets.
  static double ringDiameterFor(Size size, {double override = 0}) {
    if (override > 0) return override.clamp(280.0, size.shortestSide * 0.92);
    final shortest = size.shortestSide;
    if (shortest >= 700) return shortest * 0.58;
    if (shortest >= 600) return shortest * 0.68;
    return shortest * 0.84;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final shortest = size.shortestSide;
    final ringSize = ringDiameterFor(size, override: diameter)
        .clamp(300.0, shortest * 0.92);
    final holeRadius = ringSize / 2 + 6;
    final accent = accentColor ??
        (isComplete || isLocked ? const Color(0xFF34C759) : Colors.white);

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _FaceIdDimMaskPainter(
              holeRadius: holeRadius,
              accent: accent,
              isComplete: isComplete,
            ),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (showHeader)
                    _GlassHeader(
                      title: headline,
                      subtitle: subtitle,
                    )
                  else
                    const SizedBox(height: 8),
                  const Spacer(),
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        FaceIdProgressRing(
                          progress: ringProgress,
                          diameter: ringSize.toDouble(),
                          isCapturing: isCapturing,
                          isComplete: isComplete,
                          isLocked: isLocked,
                          faceDotOffset: faceDotOffset,
                          ringColor: accent,
                        ),
                        if (arrowDirection != null && !isComplete && !isLocked)
                          _DirectionalArrow(
                            direction: arrowDirection!,
                            color: accent,
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _GuidanceBlock(
                    guidance: guidance,
                    detail: detail,
                    isComplete: isComplete,
                    accent: accent,
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionalArrow extends StatefulWidget {
  const _DirectionalArrow({required this.direction, required this.color});

  final FaceIdArrowDirection direction;
  final Color color;

  @override
  State<_DirectionalArrow> createState() => _DirectionalArrowState();
}

class _DirectionalArrowState extends State<_DirectionalArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final angle = switch (widget.direction) {
      FaceIdArrowDirection.left => 3.141592653589793,
      FaceIdArrowDirection.right => 0.0,
      FaceIdArrowDirection.up => -1.5707963267948966,
      FaceIdArrowDirection.down => 1.5707963267948966,
    };

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        final dy = (0.5 - t) * 10;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: angle,
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 56,
              color: widget.color.withValues(alpha: 0.88),
            ),
          ),
        );
      },
    );
  }
}

class _GlassHeader extends StatelessWidget {
  const _GlassHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidanceBlock extends StatelessWidget {
  const _GuidanceBlock({
    required this.guidance,
    required this.detail,
    required this.isComplete,
    required this.accent,
  });

  final String guidance;
  final String? detail;
  final bool isComplete;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Column(
        key: ValueKey('${guidance}__${detail ?? ''}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            guidance,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isComplete ? accent : Colors.white.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              height: 1.3,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaceIdDimMaskPainter extends CustomPainter {
  _FaceIdDimMaskPainter({
    required this.holeRadius,
    required this.accent,
    required this.isComplete,
  });

  final double holeRadius;
  final Color accent;
  final bool isComplete;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Premium dark gradient base.
    final bg = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Colors.black.withValues(alpha: 0.30),
          Colors.black.withValues(alpha: 0.78),
        ],
        stops: const [0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Circular portal cutout (camera shows through).
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: holeRadius));
    canvas.drawPath(
      cutout,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Subtle inner ring border around the portal.
    final border = Paint()
      ..color = (isComplete ? accent : Colors.white).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, holeRadius, border);
  }

  @override
  bool shouldRepaint(covariant _FaceIdDimMaskPainter old) =>
      old.holeRadius != holeRadius ||
      old.accent != accent ||
      old.isComplete != isComplete;
}

/// Kiosk recognition overlay — animates a soft pulse while scanning, then
/// flips to a verified state with a green ring + check + welcome message.
class FaceIdRecognitionOverlay extends StatefulWidget {
  const FaceIdRecognitionOverlay({
    super.key,
    required this.status,
    this.isVerified = false,
    this.isScanning = true,
    this.subtitle,
  });

  final String status;
  final String? subtitle;
  final bool isVerified;
  final bool isScanning;

  @override
  State<FaceIdRecognitionOverlay> createState() =>
      _FaceIdRecognitionOverlayState();
}

class _FaceIdRecognitionOverlayState extends State<FaceIdRecognitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final progress = widget.isVerified
            ? 1.0
            : widget.isScanning
                ? 0.10 + _pulse.value * 0.20
                : 0.06;
        return FaceIdScannerOverlay(
          ringProgress: progress,
          headline: widget.isVerified
              ? FaceIdStrings.welcomeBack
              : FaceIdStrings.title,
          subtitle: widget.subtitle,
          guidance: widget.status,
          isCapturing: widget.isScanning && !widget.isVerified,
          isComplete: widget.isVerified,
          isLocked: widget.isVerified,
        );
      },
    );
  }
}
