import 'dart:io';

import 'package:attendance_kiosk_app/app/attendance_app.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kiosk_test_');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>(HiveBoxes.app);
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  testWidgets('App boots to registration when kiosk is not configured', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AttendanceApp()));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegistrationStrings.formTitle), findsOneWidget);
  });
}
