import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/routing/morph_navigator.dart';
import 'package:shifttac/core/routing/morph_page_route.dart';
import 'package:shifttac/core/routing/morph_source_rect.dart';

void main() {
  group('MorphSourceRect.tryMeasure', () {
    test('returns null when key has no context', () {
      final key = GlobalKey();
      expect(MorphSourceRect.tryMeasure(key), isNull);
    });

    testWidgets('returns global bounds when key is attached', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              key: key,
              width: 120,
              height: 48,
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      );

      final rect = MorphSourceRect.tryMeasure(key);
      expect(rect, isNotNull);
      expect(rect!.width, 120);
      expect(rect.height, 48);
    });
  });

  group('MorphNavigator.pushFrom', () {
    ModalRoute<dynamic>? routeForDestination(WidgetTester tester) {
      final element = tester.element(find.text('destination'));
      return ModalRoute.of(element);
    }

    testWidgets('falls back to MaterialPageRoute when source is not measured', (
      tester,
    ) async {
      final unattachedKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      MorphNavigator.pushFrom<void>(
                        context: context,
                        sourceKey: unattachedKey,
                        builder: (_) => const Scaffold(
                          body: Center(child: Text('destination')),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('destination'), findsOneWidget);
      final route = routeForDestination(tester);
      expect(route, isA<MaterialPageRoute<void>>());
      expect(route, isNot(isA<MorphPageRoute<void>>()));
    });

    testWidgets('uses MorphPageRoute when source can be measured', (
      tester,
    ) async {
      final sourceKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      key: sourceKey,
                      width: 160,
                      height: 72,
                      child: const ColoredBox(color: Colors.teal),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        MorphNavigator.pushFrom<void>(
                          context: context,
                          sourceKey: sourceKey,
                          builder: (_) => const Scaffold(
                            body: Center(child: Text('destination')),
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('destination'), findsOneWidget);
      final route = routeForDestination(tester);
      expect(route, isA<MorphPageRoute<void>>());
    });
  });

  group('MorphNavigator.pushFromRect', () {
    testWidgets('pushes MorphPageRoute with explicit source rect', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      MorphNavigator.pushFromRect<void>(
                        context: context,
                        sourceRect: const Rect.fromLTWH(24, 48, 100, 50),
                        builder: (_) => const Scaffold(
                          body: Center(child: Text('destination')),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('destination'), findsOneWidget);
      final element = tester.element(find.text('destination'));
      final route = ModalRoute.of(element);
      expect(route, isA<MorphPageRoute<void>>());
      expect((route! as MorphPageRoute<void>).sourceRect,
          const Rect.fromLTWH(24, 48, 100, 50));
    });
  });
}
