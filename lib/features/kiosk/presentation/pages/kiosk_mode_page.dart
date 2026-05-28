import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/config/attendance_mode.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_camera_panel.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_mode_view.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_pin_attendance_panel.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_pin_login_panel.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_sidebar.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

/// Offline-first kiosk shell: responsive sidebar (drawer in portrait) + attendance modes.
class KioskModePage extends ConsumerStatefulWidget {
  const KioskModePage({super.key});

  @override
  ConsumerState<KioskModePage> createState() => _KioskModePageState();
}

class _KioskModePageState extends ConsumerState<KioskModePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  KioskModeView _view = KioskModeView.faceScan;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  KioskModeView _defaultView(AttendanceMode mode) {
    return mode == AttendanceMode.pin
        ? KioskModeView.pinAttendance
        : KioskModeView.faceScan;
  }

  /// Portrait and narrow widths use a closed-by-default drawer; landscape tablets keep a rail.
  static bool _useDrawer(BuildContext context, AppBreakpointSize bp) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return portrait || bp == AppBreakpointSize.compact;
  }

  static double _sidebarWidth(AppBreakpointSize bp, double maxWidth) {
    if (bp == AppBreakpointSize.expanded) return 280;
    if (bp == AppBreakpointSize.medium) return 260;
    return math.min(280, maxWidth * 0.82);
  }

  Widget _mainContent(AttendanceMode mode, KioskModeView defaultView) {
    return switch (_view) {
      KioskModeView.faceScan => const KioskCameraPanel(),
      KioskModeView.pinAttendance => KioskPinAttendancePanel(
        onOpenLogin: () => setState(() => _view = KioskModeView.pinLogin),
      ),
      KioskModeView.pinLogin => KioskPinLoginPanel(
        onCancel: () => setState(() => _view = defaultView),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(kioskConfigProvider);
    final mode = configAsync.valueOrNull?.attendanceMode ?? AttendanceMode.face;
    final defaultView = _defaultView(mode);
    if (_view != KioskModeView.pinLogin &&
        ((mode == AttendanceMode.face &&
                _view == KioskModeView.pinAttendance) ||
            (mode == AttendanceMode.pin && _view == KioskModeView.faceScan))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _view = defaultView);
      });
    }

    final sidebar = KioskSidebar(
      currentView: _view,
      onViewChanged: (v) {
        setState(() => _view = v);
        _scaffoldKey.currentState?.closeDrawer();
      },
    );

    return ResponsiveBuilder(
      builder: (context, bp, constraints) {
        final useDrawer = _useDrawer(context, bp);
        final content = _mainContent(mode, defaultView);

        if (useDrawer) {
          return Scaffold(
            key: _scaffoldKey,
            drawerEnableOpenDragGesture: true,
            drawer: Drawer(
              width: _sidebarWidth(bp, constraints.maxWidth),
              child: sidebar,
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                content,
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.92),
                        elevation: 2,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          tooltip: 'Menu',
                          icon: const Icon(Icons.menu_rounded),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final railWidth = _sidebarWidth(bp, constraints.maxWidth);
        return Scaffold(
          body: Row(
            children: [
              SizedBox(width: railWidth, child: sidebar),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}
