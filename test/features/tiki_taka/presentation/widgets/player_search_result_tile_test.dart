import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_player_search_result.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/player_avatar.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/player_search_result_tile.dart';

const _validCommonsUrl =
    'https://commons.wikimedia.org/wiki/Special:FilePath/Mohamed%20Salah%202018.jpg?width=128';

const _playerWithoutImage = TikiPlayerSearchResult(
  id: 'tm:1',
  displayName: 'Test Player',
  position: 'Striker',
  nation: 'England',
);

const _playerWithImage = TikiPlayerSearchResult(
  id: 'tm:148455',
  displayName: 'Mohamed Salah',
  position: 'Right Winger',
  nation: 'Egypt',
  imageUrl: _validCommonsUrl,
);

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, _) => MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerSearchResultTile', () {
    testWidgets('null imageUrl shows person placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerSearchResultTile(
            player: _playerWithoutImage,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(PlayerAvatar), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('valid imageUrl includes PlayerAvatar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerSearchResultTile(
            player: _playerWithImage,
            onTap: () {},
          ),
        ),
      );

      final avatar = tester.widget<PlayerAvatar>(find.byType(PlayerAvatar));
      expect(avatar.imageUrl, _validCommonsUrl);
    });

    testWidgets('preserves row semantics label with subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerSearchResultTile(
            player: _playerWithoutImage,
            onTap: () {},
          ),
        ),
      );

      final rowSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((semantics) => semantics.properties.button == true);

      expect(
        rowSemantics.properties.label,
        'Test Player, Striker · England',
      );
    });

    testWidgets('onTap fires when enabled', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          PlayerSearchResultTile(
            player: _playerWithoutImage,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(PlayerSearchResultTile));
      expect(tapped, isTrue);
    });

    testWidgets('onTap does not fire when disabled', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          PlayerSearchResultTile(
            player: _playerWithoutImage,
            enabled: false,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(PlayerSearchResultTile));
      expect(tapped, isFalse);
    });
  });
}
