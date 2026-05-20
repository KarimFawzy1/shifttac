import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shifttac/app.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';

void main() {
  testWidgets('ShiftTacApp boots with MaterialApp', (WidgetTester tester) async {
    final settings = AppSettingsController();
    await tester.pumpWidget(
      ShiftTacApp(settings: settings, audio: AppAudio(settings)),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
