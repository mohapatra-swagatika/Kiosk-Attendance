import 'package:flutter/material.dart';

/// One row in the kiosk bootstrap checklist.
class KioskLoadingStep {
  const KioskLoadingStep({
    required this.label,
    this.complete = false,
    this.active = false,
  });

  final String label;
  final bool complete;
  final bool active;
}

/// Full-screen loading state — spinner stays visible until the camera feed is live.
class KioskCameraLoadingView extends StatefulWidget {
  const KioskCameraLoadingView({
    super.key,
    required this.message,
    this.subtitle,
    this.steps = const [],
    this.showRetry = false,
    this.onRetry,
  });

  final String message;
  final String? subtitle;
  final List<KioskLoadingStep> steps;
  final bool showRetry;
  final VoidCallback? onRetry;

  @override
  State<KioskCameraLoadingView> createState() => _KioskCameraLoadingViewState();
}

class _KioskCameraLoadingViewState extends State<KioskCameraLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.55, end: 1.0).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                    ),
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (widget.steps.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    ...widget.steps.map(_StepRow.new),
                  ],
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(
                    minHeight: 3,
                    color: Colors.white54,
                    backgroundColor: Colors.white12,
                  ),
                  if (widget.showRetry && widget.onRetry != null) ...[
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: widget.onRetry,
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Semi-transparent banner during first live recognition (preview keeps updating).
class KioskInlineProcessingOverlay extends StatelessWidget {
  const KioskInlineProcessingOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.42),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.step);

  final KioskLoadingStep step;

  @override
  Widget build(BuildContext context) {
    final color = step.complete
        ? const Color(0xFF34C759)
        : step.active
            ? Colors.white
            : Colors.white38;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: step.complete
                ? Icon(Icons.check_circle_rounded, color: color, size: 22)
                : step.active
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : Icon(Icons.circle_outlined, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: step.active ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
