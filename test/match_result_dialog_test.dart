import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/constants/image_constants.dart';
import 'package:shifttac/core/routing/app_routes.dart';
import 'package:shifttac/features/game/presentation/widgets/match_result.dart';
import 'package:shifttac/features/game/presentation/widgets/match_result_dialog.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required MatchResult result,
    VoidCallback? onPlayAgain,
    VoidCallback? onBackToHome,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (_, __) => MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => MatchResultDialog.show(
                      context,
                      result: result,
                      onPlayAgain: onPlayAgain ?? () {},
                      onBackToHome: onBackToHome ?? () {},
                    ),
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(MatchResultDialog.animationDuration);
  }

  group('MatchResultDialog', () {
    testWidgets('X win shows title, body, stats, and actions', (
      WidgetTester tester,
    ) async {
      await pumpDialog(
        tester,
        result: MatchResult.xWin(totalMoves: 7, matchDurationMs: 125_000),
      );

      expect(find.text('X Wins!'), findsOneWidget);
      expect(find.text('Strategic mastery achieved.'), findsOneWidget);
      expect(find.text('Total moves'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Match time'), findsOneWidget);
      expect(find.text('2:05'), findsOneWidget);
      expect(find.text('Play Again'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
      expect(find.byType(SvgPicture), findsWidgets);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName ==
                  IconConstant.x,
        ),
        findsOneWidget,
      );
    });

    testWidgets('O win shows O symbol and green palette', (
      WidgetTester tester,
    ) async {
      await pumpDialog(
        tester,
        result: MatchResult.oWin(totalMoves: 5, matchDurationMs: 30_000),
      );

      expect(find.text('O Wins!'), findsOneWidget);
      expect(find.text("It's a Draw!"), findsNothing);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName ==
                  IconConstant.o,
        ),
        findsOneWidget,
      );
    });

    testWidgets('draw shows draw asset, neutral copy, and grey palette', (
      WidgetTester tester,
    ) async {
      await pumpDialog(
        tester,
        result: MatchResult.draw(totalMoves: 9, matchDurationMs: 60_000),
      );

      expect(find.text("It's a Draw!"), findsOneWidget);
      expect(
        find.text('No winner this round. Try another match.'),
        findsOneWidget,
      );
      expect(find.text('X Wins!'), findsNothing);
      expect(find.text('O Wins!'), findsNothing);
      expect(find.text('Strategic mastery achieved.'), findsNothing);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName ==
                  IconConstant.draw,
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName ==
                  IconConstant.x,
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName ==
                  IconConstant.o,
        ),
        findsNothing,
      );
    });

    testWidgets('Play Again dismisses dialog and invokes callback', (
      WidgetTester tester,
    ) async {
      var playAgainCalled = false;

      await pumpDialog(
        tester,
        result: MatchResult.draw(totalMoves: 9, matchDurationMs: 0),
        onPlayAgain: () => playAgainCalled = true,
      );

      await tester.tap(find.text('Play Again'));
      await tester.pumpAndSettle();

      expect(playAgainCalled, isTrue);
      expect(find.text("It's a Draw!"), findsNothing);
    });

    testWidgets('Back to Home dismisses dialog and invokes callback', (
      WidgetTester tester,
    ) async {
      var backHomeCalled = false;

      await pumpDialog(
        tester,
        result: MatchResult.xWin(totalMoves: 3, matchDurationMs: 0),
        onBackToHome: () => backHomeCalled = true,
      );

      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(backHomeCalled, isTrue);
      expect(find.text('X Wins!'), findsNothing);
    });

    testWidgets('Back to Home navigates to home route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: AppConstants.designSize,
          builder: (_, __) => MaterialApp(
            routes: {
              AppRoutes.home: (_) =>
                  const Scaffold(body: Center(child: Text('home screen'))),
            },
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => MatchResultDialog.show(
                      context,
                      result: MatchResult.draw(
                        totalMoves: 9,
                        matchDurationMs: 0,
                      ),
                      onPlayAgain: () {},
                      onBackToHome: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.home,
                          (route) => false,
                        );
                      },
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(MatchResultDialog.animationDuration);

      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
    });
  });
}
