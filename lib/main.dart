import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/app/bootstrap_gate.dart';

Future<void> main() async {
  // runApp on the first frame — never await heavy ML/Firebase work before this.
  runApp(const BootstrapGate());
}
