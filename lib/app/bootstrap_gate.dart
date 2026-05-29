import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/app/attendance_app.dart';
import 'package:attendance_kiosk_app/app/bootstrap.dart';
/// Shows UI immediately, then finishes ML init in the background (avoids iOS launch hang).
class BootstrapGate extends StatefulWidget {
  const BootstrapGate({super.key});

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate> {
  String? _error;
  bool _ready = false;
  String _status = 'Starting…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final error = await bootstrap(
      onStatus: (msg) {
        if (mounted) setState(() => _status = msg);
      },
    );
    if (!mounted) return;
    setState(() {
      _error = error;
      _ready = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return bootstrapErrorApp(_error!);
    }
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white70),
                const SizedBox(height: 20),
                Text(
                  _status,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const ProviderScope(child: AttendanceApp());
  }
}
