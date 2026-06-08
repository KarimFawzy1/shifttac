import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_attribute.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_board.dart';
import 'package:shifttac/features/tiki_taka/domain/logic/tiki_taka_game_engine.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_status.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_state.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_completion_dialog.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_first_win_dialog.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_lost_dialog.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_pause_sheet.dart';

import 'tiki_taka_dao_test_support.dart';

export 'tiki_taka_dao_test_support.dart';

const testBoard = TikiBoard(
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

TikiTakaDependencies tikiDialogTestDependencies(
  TikiTakaTestDatabaseHandle handle,
) {
  return tikiTakaTestDependencies(handle);
}

TikiTakaCubit seedTikiCubit({
  required TikiTakaTestDatabaseHandle handle,
  required TikiGameStatus status,
  Duration elapsed = const Duration(minutes: 2, seconds: 5),
  int hearts = 3,
}) {
  final engine = TikiTakaGameEngine.instance;
  final game = engine.boardLoaded(engine.initial(), testBoard).copyWith(
        status: status,
        elapsed: elapsed,
        hearts: hearts,
      );
  return TikiTakaCubit.forTest(
    dependencies: tikiDialogTestDependencies(handle),
    initialState: TikiTakaState.initial(game),
  );
}

Widget wrapTikiDialogTest({
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

void resetTikiDialogVisibilityForTest() {
  TikiTakaFirstWinDialog.resetVisibilityForTest();
  TikiTakaCompletionDialog.resetVisibilityForTest();
  TikiTakaLostDialog.resetVisibilityForTest();
  TikiTakaPauseSheet.resetVisibilityForTest();
}
