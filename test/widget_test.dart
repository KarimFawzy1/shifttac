import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shifttac/app.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';

void main() {
  testWidgets('ShiftTacApp boots with MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      ShiftTacApp(settings: AppSettingsController()),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
