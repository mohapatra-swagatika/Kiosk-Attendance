import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/widgets/glass_panel.dart';

/// “Active attendance” status row: stream health + face presence (MD §5).
class ActiveAttendanceStrip extends StatelessWidget {
  const ActiveAttendanceStrip({
    super.key,
    required this.cameraLive,
    required this.faceCount,
    this.initializing = false,
    this.errorMessage,
  });

  final bool cameraLive;
  final int faceCount;
  final bool initializing;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = errorMessage != null
        ? 'Attention'
        : initializing
            ? 'Starting…'
            : cameraLive
                ? 'Active scan'
                : 'Standby';
    final detail = errorMessage ??
        (initializing
            ? 'Preparing camera and ML Kit…'
            : cameraLive
                ? faceCount > 0
                    ? '$faceCount face${faceCount == 1 ? '' : 's'} in frame'
                    : 'No face in frame — ask guest to step in'
                : 'Camera stream paused');

    final color = errorMessage != null
        ? scheme.error
        : initializing
            ? scheme.tertiary
            : cameraLive
                ? scheme.primary
                : scheme.outline;

    return GlassPanel(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _PulseDot(active: cameraLive && errorMessage == null && !initializing, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void didUpdateWidget(covariant _PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = CurvedAnimation(parent: _c, curve: Curves.easeOut).value;
        return SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 14 + 10 * t,
                height: 14 + 10 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.15 * (1 - t)),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
