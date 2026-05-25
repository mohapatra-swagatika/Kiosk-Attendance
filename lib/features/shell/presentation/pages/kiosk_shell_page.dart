import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:attendance_kiosk_app/app/theme/app_colors.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/core/widgets/glass_panel.dart';
import 'package:attendance_kiosk_app/features/shell/presentation/widgets/kiosk_drawer.dart';

class KioskShellPage extends ConsumerWidget {
  const KioskShellPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveBuilder(
      builder: (context, size, constraints) {
        final wide = size != AppBreakpointSize.compact;
        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.appTitle),
          ),
          drawer: wide ? null : const KioskDrawer(),
          body: Row(
            children: [
              if (wide) const SizedBox(width: 280, child: Drawer(child: KioskDrawerContent())),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.scaffoldGradient(Theme.of(context).brightness),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GlassPanel(
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
