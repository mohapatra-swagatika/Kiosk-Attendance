import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';

/// Pads content and constrains max width for kiosk / tablet readability.
class DashboardPageChrome extends StatelessWidget {
  const DashboardPageChrome({
    super.key,
    required this.child,
    this.maxContentWidth = 1120,
  });

  final Widget child;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, bp, _) {
        final horizontal = switch (bp) {
          AppBreakpointSize.compact => 16.0,
          AppBreakpointSize.medium => 24.0,
          AppBreakpointSize.expanded => 32.0,
        };
        final vertical = switch (bp) {
          AppBreakpointSize.compact => 16.0,
          AppBreakpointSize.medium => 20.0,
          AppBreakpointSize.expanded => 24.0,
        };
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
