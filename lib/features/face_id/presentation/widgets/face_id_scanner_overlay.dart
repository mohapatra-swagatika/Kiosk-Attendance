import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/features/face_id/presentation/widgets/face_id_circular_camera_preview.dart';
import 'package:attendance_kiosk_app/features/face_id/presentation/widgets/face_id_progress_ring.dart';

enum FaceIdArrowDirection { left, right, up, down }

/// Shared Face ID portal geometry (ring + circular camera cutout).
class FaceIdPortalGeometry {
  const FaceIdPortalGeometry({
    required this.ringDiameter,
    required this.portalDiameter,
    required this.portalRadius,
  });

  final double ringDiameter;
  final double portalDiameter;
  final double portalRadius;

  static FaceIdPortalGeometry forScreen(Size size, {double diameterOverride = 0}) {
    final ringDiameter = FaceIdScannerOverlay.ringDiameterFor(
      size,
      override: diameterOverride,
    );
    // Portal sits flush inside the progress ring stroke.
    const portalInset = 6.0;
    final portalDiameter = ringDiameter - portalInset * 2;
    return FaceIdPortalGeometry(
      ringDiameter: ringDiameter,
      portalDiameter: portalDiameter.clamp(260.0, size.shortestSide * 0.88),
      portalRadius: (portalDiameter.clamp(260.0, size.shortestSide * 0.88)) / 2,
    );
  }
}

/// Premium Face ID overlay used by enrollment and recognition.
///
/// When [cameraController] is set (enrollment), the live camera is clipped to the
/// circular portal only; header/footer stay on a black canvas.
///
/// When [cameraController] is set (enrollment + kiosk), the live feed is clipped
/// to the circular portal; surrounding UI is black.
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
    this.highlightDirection = false,
    this.accentColor,
    this.showHeader = true,
    this.cameraController,
    this.cameraLoading = false,
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
  final bool highlightDirection;
  final Color? accentColor;
  final bool showHeader;

  /// When non-null, preview is rendered only inside the circular portal.
  final CameraController? cameraController;

  /// Shown in the portal while the camera is opening.
  final bool cameraLoading;

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
    final size = MediaQuery.sizeOf(context);
    final geometry = FaceIdPortalGeometry.forScreen(size, diameterOverride: diameter);
    final accent = accentColor ??
        (isComplete || isLocked ? const Color(0xFF34C759) : Colors.white);
    final portalOnly = cameraController != null || cameraLoading;

    final content = SafeArea(
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
            Expanded(
              child: _FaceIdPortalStage(
                geometry: geometry,
                accent: accent,
                isComplete: isComplete,
                portalOnly: portalOnly,
                cameraController: cameraController,
                cameraLoading: cameraLoading,
                ringProgress: ringProgress,
                isCapturing: isCapturing,
                isLocked: isLocked,
                faceDotOffset: faceDotOffset,
                arrowDirection: arrowDirection,
                highlightDirection: highlightDirection,
              ),
            ),
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
    );

    return ColoredBox(
      color: Colors.black,
      child: IgnorePointer(child: content),
    );
  }
}

class _FaceIdPortalStage extends StatelessWidget {
  const _FaceIdPortalStage({
    required this.geometry,
    required this.accent,
    required this.isComplete,
    required this.portalOnly,
    required this.cameraController,
    required this.cameraLoading,
    required this.ringProgress,
    required this.isCapturing,
    required this.isLocked,
    required this.faceDotOffset,
    required this.arrowDirection,
    required this.highlightDirection,
  });

  final FaceIdPortalGeometry geometry;
  final Color accent;
  final bool isComplete;
  final bool portalOnly;
  final CameraController? cameraController;
  final bool cameraLoading;
  final double ringProgress;
  final bool isCapturing;
  final bool isLocked;
  final Offset? faceDotOffset;
  final FaceIdArrowDirection? arrowDirection;
  final bool highlightDirection;

  @override
  Widget build(BuildContext context) {
    final portalSize = geometry.portalDiameter;

    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        if (portalOnly) ...[
          Center(
            child: SizedBox(
              width: portalSize,
              height: portalSize,
              child: ClipOval(
                child: _portalCameraContent(),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: portalSize,
              height: portalSize,
              child: CustomPaint(
                painter: _FaceIdPortalRingPainter(
                  accent: accent,
                  isComplete: isComplete,
                ),
              ),
            ),
          ),
        ],
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              FaceIdProgressRing(
                progress: ringProgress,
                diameter: geometry.ringDiameter,
                isCapturing: isCapturing,
                isComplete: isComplete,
                isLocked: isLocked,
                faceDotOffset: faceDotOffset,
                ringColor: accent,
              ),
              if (arrowDirection != null && !isComplete && !isLocked)
                _DirectionalArrow(
                  direction: arrowDirection!,
                  color: highlightDirection
                      ? const Color(0xFF34C759)
                      : accent,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _portalCameraContent() {
    if (cameraController != null &&
        cameraController!.value.isInitialized) {
      return FaceIdCircularCameraPreview(controller: cameraController!);
    }
    if (cameraLoading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }
    return const ColoredBox(color: Colors.black);
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

/// Subtle outer vignette around the enrollment portal (outside stays black).
class _FaceIdPortalRingPainter extends CustomPainter {
  _FaceIdPortalRingPainter({
    required this.accent,
    required this.isComplete,
  });

  final Color accent;
  final bool isComplete;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
        ],
        stops: const [0.82, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, vignette);

    final border = Paint()
      ..color = (isComplete ? accent : Colors.white).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius - 0.6, border);
  }

  @override
  bool shouldRepaint(covariant _FaceIdPortalRingPainter old) =>
      old.accent != accent || old.isComplete != isComplete;
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
    this.cameraController,
    this.cameraLoading = false,
  });

  final String status;
  final String? subtitle;
  final bool isVerified;
  final bool isScanning;
  final CameraController? cameraController;
  final bool cameraLoading;

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
          cameraController: widget.cameraController,
          cameraLoading: widget.cameraLoading,
          ringProgress: progress,
          headline: widget.isVerified
              ? FaceIdStrings.welcomeBack
              : FaceIdStrings.title,
          guidance: widget.status,
          isCapturing: widget.isScanning && !widget.isVerified,
          isComplete: widget.isVerified,
          isLocked: widget.isVerified,
        );
      },
    );
  }
}
