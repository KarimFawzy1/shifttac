import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_attribute.dart';
import 'package:shifttac/features/tiki_taka/domain/services/tiki_attribute_asset_manifest.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_attribute_header.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_attribute_icon.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_attribute_svg_asset.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_board_frame.dart';

const _liverpoolClub = TikiAttribute(
  id: 'club:31',
  type: 'club',
  displayName: 'Liverpool',
  slug: 'liverpool',
  iconKey: 'club_31',
);

const _egyptNation = TikiAttribute(
  id: 'nation:egypt',
  type: 'nation',
  displayName: 'Egypt',
  slug: 'egypt',
  iconKey: 'nation_egypt',
);

const _premierLeague = TikiAttribute(
  id: 'league:gb1',
  type: 'league',
  displayName: 'Premier League',
  slug: 'premier-league',
  iconKey: 'league_gb1',
);

const _forwardPosition = TikiAttribute(
  id: 'pos:fwd',
  type: 'position',
  displayName: 'Forward',
  slug: 'forward',
  iconKey: 'pos_fwd',
);

const _missingClub = TikiAttribute(
  id: 'club:missing',
  type: 'club',
  displayName: 'Missing Club',
  slug: 'missing-club',
  iconKey: 'club_missing_test',
);

Future<TikiAttributeAssetManifest> _loadProductionManifest() {
  return TikiAttributeAssetManifest.load();
}

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, _) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 390, height: 844, child: child)),
    ),
  );
}

Finder _svgWithAsset(String assetPath) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TikiAttributeSvgAsset && widget.assetPath == assetPath,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikiAttributeAssetManifest manifest;

  setUpAll(() async {
    manifest = await _loadProductionManifest();
  });

  group('TikiAttributeHeader', () {
    Future<void> pumpHeader(
      WidgetTester tester, {
      required TikiAttribute attribute,
      TikiHeaderAxis axis = TikiHeaderAxis.column,
    }) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Center(
              child: SizedBox(
                width: 72,
                height: 72,
                child: TikiAttributeHeader(
                  attribute: attribute,
                  manifest: manifest,
                  axis: axis,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('club header displays SVG', (tester) async {
      await pumpHeader(tester, attribute: _liverpoolClub);

      expect(
        _svgWithAsset('assets/tiki_taka/attrs/clubs/Liverpool.svg'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Club: Liverpool'), findsOneWidget);
    });

    testWidgets('nation header displays SVG', (tester) async {
      await pumpHeader(tester, attribute: _egyptNation);

      expect(
        _svgWithAsset('assets/tiki_taka/attrs/nations/Egypt.svg'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Nation: Egypt'), findsOneWidget);
    });

    testWidgets('league header displays SVG', (tester) async {
      await pumpHeader(tester, attribute: _premierLeague);

      expect(
        _svgWithAsset('assets/tiki_taka/attrs/leagues/Premier-League.svg'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('League: Premier League'), findsOneWidget);
    });

    testWidgets('position header displays short code text only', (tester) async {
      await pumpHeader(tester, attribute: _forwardPosition);

      expect(find.text('FWD'), findsOneWidget);
      expect(find.text('Forward'), findsNothing);
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.bySemanticsLabel('Position: Forward'), findsOneWidget);
    });

    testWidgets('missing asset has a graceful fallback', (tester) async {
      final emptyManifest = TikiAttributeAssetManifest.forTest({});

      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: TikiAttributeHeader(
                attribute: _missingClub,
                manifest: emptyManifest,
                axis: TikiHeaderAxis.column,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('MC'), findsOneWidget);
      expect(find.bySemanticsLabel('Club: Missing Club'), findsOneWidget);
    });
  });

  group('TikiAttributeIcon', () {
    testWidgets('icon resolves manifest paths without display-name guessing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(TikiAttributeIcon(attribute: _liverpoolClub, manifest: manifest)),
      );
      await tester.pumpAndSettle();

      expect(
        manifest.pathForIconKey('club_31'),
        'assets/tiki_taka/attrs/clubs/Liverpool.svg',
      );
      expect(
        _svgWithAsset('assets/tiki_taka/attrs/clubs/Liverpool.svg'),
        findsOneWidget,
      );
    });
  });

  group('TikiBoardFrame', () {
    testWidgets('renders three row and three column headers', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 320,
            height: 360,
            child: TikiBoardFrame(
              rowHeaders: const [
                _egyptNation,
                _forwardPosition,
                _premierLeague,
              ],
              columnHeaders: const [
                _liverpoolClub,
                _premierLeague,
                _egyptNation,
              ],
              manifest: manifest,
              board: const ColoredBox(color: Color(0xFFE0E0E0)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TikiAttributeHeader), findsNWidgets(6));
      expect(find.text('FWD'), findsOneWidget);
      expect(
        _svgWithAsset('assets/tiki_taka/attrs/clubs/Liverpool.svg'),
        findsOneWidget,
      );
    });
  });
}
