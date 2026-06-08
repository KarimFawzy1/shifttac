import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/how_to_play/presentation/screens/how_to_play_screen.dart';
import 'package:shifttac/features/tiki_taka/presentation/screens/tiki_taka_gameplay_screen.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';

Widget _howToPlayTestApp({required bool standalone}) {
  return ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, child) => MaterialApp(
      home: HowToPlayScreen(standalone: standalone),
    ),
  );
}

Future<void> _pumpHowToPlay(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _disposeHowToPlay(WidgetTester tester) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: AppConstants.designSize,
      builder: (context, child) => const MaterialApp(home: SizedBox.shrink()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
}

void main() {
  group('HowToPlayScreen', () {
    testWidgets('renders ShiftTac rules in shell mode', (tester) async {
      await _pumpHowToPlay(tester, _howToPlayTestApp(standalone: false));

      expect(find.text('How to Play'), findsOneWidget);
      expect(find.text('ShiftTac and Tiki-Taka rules.'), findsOneWidget);
      expect(find.text('ShiftTac'), findsWidgets);
      expect(
        find.text(
          'Each player may only have three marks on the board at once.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('First player to line up three active marks in a row wins.'),
        findsOneWidget,
      );

      await _disposeHowToPlay(tester);
    });

    testWidgets('renders Tiki-Taka rules with fixture copy', (tester) async {
      await _pumpHowToPlay(tester, _howToPlayTestApp(standalone: false));

      await _scrollTo(tester, find.text('Tiki-Taka').last);
      await _scrollTo(tester, find.text('Five hearts'));

      expect(
        find.text('Football knowledge on a 3×3 board. Solo mode — no AI.'),
        findsOneWidget,
      );
      expect(find.text('Five hearts'), findsOneWidget);
      expect(find.text('One player per board'), findsOneWidget);
      expect(find.text('First line wins'), findsOneWidget);
      expect(find.text('Full board challenge'), findsOneWidget);
      expect(find.text('Match timer'), findsOneWidget);
      expect(find.text('Liverpool × Egypt'), findsOneWidget);
      expect(find.textContaining('free-text confirmation'), findsOneWidget);
      expect(find.textContaining('already used'), findsWidgets);
      expect(find.textContaining('timer keeps running'), findsOneWidget);

      await _disposeHowToPlay(tester);
    });

    testWidgets('does not mount live Tiki-Taka gameplay state', (tester) async {
      await _pumpHowToPlay(tester, _howToPlayTestApp(standalone: false));

      expect(find.byType(TikiTakaGameplayScreen), findsNothing);
      expect(find.byType(TikiTakaCubit), findsNothing);

      await _disposeHowToPlay(tester);
    });

    testWidgets('compact standalone mode keeps core ShiftTac steps', (
      tester,
    ) async {
      await _pumpHowToPlay(tester, _howToPlayTestApp(standalone: true));

      expect(find.text('Shifts and faded marks'), findsOneWidget);
      expect(find.text('How to win'), findsOneWidget);
      expect(
        find.text('Each player may only have three marks on the board at once.'),
        findsNothing,
      );

      await _scrollTo(tester, find.text('Tiki-Taka').last);
      expect(find.text('Tiki-Taka'), findsWidgets);

      await _disposeHowToPlay(tester);
    });

    testWidgets('does not mention data pipeline internals', (tester) async {
      await _pumpHowToPlay(tester, _howToPlayTestApp(standalone: false));

      await _scrollTo(tester, find.text('Match timer'));

      expect(find.textContaining('Transfermarkt'), findsNothing);
      expect(find.textContaining('SQLite'), findsNothing);
      expect(find.textContaining('ETL'), findsNothing);

      await _disposeHowToPlay(tester);
    });
  });
}
