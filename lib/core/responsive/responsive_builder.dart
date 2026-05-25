import 'package:flutter/material.dart';

/// Layout breakpoints for kiosk / tablet / phone.
abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;
}

enum AppBreakpointSize { compact, medium, expanded }

AppBreakpointSize breakpointForWidth(double width) {
  if (width >= AppBreakpoints.expanded) return AppBreakpointSize.expanded;
  if (width >= AppBreakpoints.medium) return AppBreakpointSize.medium;
  return AppBreakpointSize.compact;
}

/// Rebuilds when width crosses [AppBreakpoints] thresholds.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context,
    AppBreakpointSize size,
    BoxConstraints constraints,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = breakpointForWidth(constraints.maxWidth);
        return builder(context, size, constraints);
      },
    );
  }
}
