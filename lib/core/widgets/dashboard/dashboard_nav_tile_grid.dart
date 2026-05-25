import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';

/// Responsive grid for [DashboardNavTile] children.
class DashboardNavTileGrid extends StatelessWidget {
  const DashboardNavTileGrid({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, bp, _) {
        final cross = switch (bp) {
          AppBreakpointSize.compact => 1,
          AppBreakpointSize.medium => 2,
          AppBreakpointSize.expanded => 2,
        };
        final aspect = switch (bp) {
          AppBreakpointSize.compact => 1.55,
          AppBreakpointSize.medium => 1.75,
          AppBreakpointSize.expanded => 2.0,
        };
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: aspect,
          children: children,
        );
      },
    );
  }
}
