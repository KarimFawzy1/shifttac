import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_attribute.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_board.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_player_search_result.dart';
import 'package:shifttac/features/tiki_taka/domain/logic/tiki_taka_game_engine.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_state.dart';
import 'package:shifttac/features/tiki_taka/domain/services/tiki_attribute_asset_manifest.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_state.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/player_search_dialog.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/player_search_result_tile.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_attribute_header.dart';

import '../../support/tiki_taka_dao_test_support.dart';

const _salah = TikiPlayerSearchResult(
  id: 'tm:148455',
  displayName: 'Mohamed Salah',
  position: 'Right Winger',
  nation: 'Egypt',
);

const _board = TikiBoard(
  id: 'test_board',
  name: 'Test Board',
  minIntersection: 1,
  rowAttributes: [
    TikiAttribute(
      id: 'club:31',
      type: 'club',
      displayName: 'Liverpool',
      slug: 'liverpool',
      iconKey: 'club_31',
    ),
    TikiAttribute(
      id: 'club:16',
      type: 'club',
      displayName: 'Borussia Dortmund',
      slug: 'borussia-dortmund',
      iconKey: 'club_16',
    ),
    TikiAttribute(
      id: 'club:27',
      type: 'club',
      displayName: 'Bayern Munich',
      slug: 'bayern-munich',
      iconKey: 'club_27',
    ),
  ],
  columnAttributes: [
    TikiAttribute(
      id: 'nation:egypt',
      type: 'nation',
      displayName: 'Egypt',
      slug: 'egypt',
      iconKey: 'nation_egypt',
    ),
    TikiAttribute(
      id: 'nation:england',
      type: 'nation',
      displayName: 'England',
      slug: 'england',
      iconKey: 'nation_england',
    ),
    TikiAttribute(
      id: 'nation:france',
      type: 'nation',
      displayName: 'France',
      slug: 'france',
      iconKey: 'nation_france',
    ),
  ],
);

Widget _wrap({
  required TikiTakaCubit cubit,
  required Widget child,
}) {
  return ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, _) => MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(value: cubit, child: child),
      ),
    ),
  );
}

TikiTakaDependencies _dependencies(TikiTakaTestDatabaseHandle handle) {
  return tikiTakaTestDependencies(handle);
}

TikiTakaCubit _createCubit(
  TikiTakaTestDatabaseHandle handle, {
  List<TikiPlayerSearchResult> searchResults = const [],
  String searchQuery = '',
  bool isSearching = false,
}) {
  final engine = TikiTakaGameEngine.instance;
  final game = engine.boardLoaded(engine.initial(), _board);
  return TikiTakaCubit.forTest(
    dependencies: _dependencies(handle),
    initialState: TikiTakaState.initial(game).copyWith(
      activeCell: const TikiActiveCell(row: 0, col: 0),
      searchQuery: searchQuery,
      searchResults: searchResults,
      isSearching: isSearching,
    ),
  );
}

Future<void> _pumpDialog(WidgetTester tester, TikiTakaCubit cubit) async {
  await tester.pumpWidget(
    _wrap(
      cubit: cubit,
      child: PlayerSearchDialog.forTest(
        routeAnimation: const AlwaysStoppedAnimation<double>(1),
        rowAttribute: _board.rowAttributes.first,
        columnAttribute: _board.columnAttributes.first,
        manifest: TikiAttributeAssetManifest.forTest(const {}),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikiTakaTestDatabaseHandle databaseHandle;
  late TikiTakaCubit cubit;

  setUpAll(ensureTikiTakaDaoTestInit);

  setUp(() async {
    PlayerSearchDialog.resetVisibilityForTest();
    databaseHandle = await openTikiTakaTestDatabase();
    cubit = _createCubit(databaseHandle);
  });

  tearDown(() async {
    await cubit.close();
    await databaseHandle.close();
    PlayerSearchDialog.resetVisibilityForTest();
  });

  testWidgets('shows cell context and empty prompt', (tester) async {
    await _pumpDialog(tester, cubit);

    expect(find.text('Find a player'), findsOneWidget);
    expect(find.byType(TikiAttributeHeader), findsNWidgets(2));
    expect(find.bySemanticsLabel('Match row Liverpool and column Egypt'), findsOneWidget);
    expect(
      find.textContaining('Search for a player who matches both attributes'),
      findsOneWidget,
    );
  });

  testWidgets('focuses search field when dialog opens', (tester) async {
    await _pumpDialog(tester, cubit);
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(PlayerSearchDialog.searchFieldKey),
    );
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('shows search results and no-results state', (tester) async {
    await cubit.close();
    cubit = _createCubit(
      databaseHandle,
      searchQuery: 'salah',
      searchResults: const [_salah],
    );

    await _pumpDialog(tester, cubit);

    expect(find.byType(PlayerSearchResultTile), findsOneWidget);
    expect(find.text('Mohamed Salah'), findsOneWidget);
    expect(find.text('Right Winger · Egypt'), findsOneWidget);

    final noResultsCubit = _createCubit(databaseHandle, searchQuery: 'zzzznotaplayer');
    await cubit.close();
    cubit = noResultsCubit;
    await _pumpDialog(tester, cubit);

    expect(find.textContaining('No players found'), findsOneWidget);
    expect(find.byType(PlayerSearchResultTile), findsNothing);
  });

  testWidgets('free-text submit does not fill a cell', (tester) async {
    await _pumpDialog(tester, cubit);

    await tester.enterText(find.byKey(PlayerSearchDialog.searchFieldKey), 'free text');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(find.byType(ElevatedButton), findsNothing);
    expect(cubit.state.game.filledCellCount, 0);
    expect(cubit.state.hearts, TikiGameState.startingHearts);
  });
}
