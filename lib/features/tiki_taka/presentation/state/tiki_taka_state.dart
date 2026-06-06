import 'package:equatable/equatable.dart';

import '../../data/models/tiki_attribute.dart';
import '../../data/models/tiki_player_search_result.dart';
import '../../domain/models/tiki_game_state.dart';
import '../../domain/models/tiki_game_status.dart';

class _Unset {
  const _Unset();
}

const Object _kUnset = _Unset();

/// Selected board cell while the player search dialog is open.
class TikiActiveCell extends Equatable {
  const TikiActiveCell({required this.row, required this.col});

  final int row;
  final int col;

  @override
  List<Object?> get props => [row, col];
}

/// UI-facing Tiki-Taka match state.
class TikiTakaState extends Equatable {
  const TikiTakaState({
    required this.game,
    this.inputLocked = false,
    this.activeCell,
    this.searchResults = const [],
    this.searchQuery = '',
    this.isSearching = false,
  });

  factory TikiTakaState.initial(TikiGameState game) {
    return TikiTakaState(game: game);
  }

  final TikiGameState game;
  final bool inputLocked;
  final TikiActiveCell? activeCell;
  final List<TikiPlayerSearchResult> searchResults;
  final String searchQuery;
  final bool isSearching;

  TikiGameStatus get status => game.status;

  int get hearts => game.hearts;

  int get elapsedMs => game.elapsed.inMilliseconds;

  List<TikiAttribute> get rowHeaders => game.board?.rowAttributes ?? const [];

  List<TikiAttribute> get columnHeaders =>
      game.board?.columnAttributes ?? const [];

  bool get isPlayable => game.isPlayable && !inputLocked;

  TikiTakaState copyWith({
    TikiGameState? game,
    Object? inputLocked = _kUnset,
    Object? activeCell = _kUnset,
    List<TikiPlayerSearchResult>? searchResults,
    Object? searchQuery = _kUnset,
    Object? isSearching = _kUnset,
    bool clearActiveCell = false,
  }) {
    return TikiTakaState(
      game: game ?? this.game,
      inputLocked: identical(inputLocked, _kUnset)
          ? this.inputLocked
          : inputLocked as bool,
      activeCell: clearActiveCell
          ? null
          : identical(activeCell, _kUnset)
          ? this.activeCell
          : activeCell as TikiActiveCell?,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: identical(searchQuery, _kUnset)
          ? this.searchQuery
          : searchQuery as String,
      isSearching: identical(isSearching, _kUnset)
          ? this.isSearching
          : isSearching as bool,
    );
  }

  @override
  List<Object?> get props => [
    game,
    inputLocked,
    activeCell,
    searchResults,
    searchQuery,
    isSearching,
  ];
}
