import 'package:equatable/equatable.dart';

import '../../domain/logic/classic_game_engine.dart';
import '../../domain/logic/game_rules.dart';
import '../../domain/logic/game_snapshot.dart';
import '../../domain/logic/shift_game_engine.dart';
import '../../domain/models/player.dart';
import '../../domain/models/position.dart';

class _Unset {
  const _Unset();
}

const Object _kUnset = _Unset();

/// UI-facing game state: engine snapshot plus presentation-only fields.
class GameState extends Equatable {
  const GameState({
    required this.snapshot,
    required this.inputLocked,
    required this.lastPlacedPosition,
    required this.lastRemovedPosition,
    required this.matchDurationMs,
  });

  factory GameState.initialFor(GameRules rules, {Player? startingPlayer}) {
    final snapshot = startingPlayer != null
        ? GameSnapshot.initial(startingPlayer: startingPlayer)
        : rules.initial();
    return GameState(
      snapshot: snapshot,
      inputLocked: false,
      lastPlacedPosition: null,
      lastRemovedPosition: null,
      matchDurationMs: 0,
    );
  }

  factory GameState.shift() => GameState.initialFor(ShiftGameEngine.instance);

  factory GameState.classic() =>
      GameState.initialFor(ClassicGameEngine.instance);

  final GameSnapshot snapshot;
  final bool inputLocked;
  final Position? lastPlacedPosition;
  final Position? lastRemovedPosition;
  final int matchDurationMs;

  GameState copyWith({
    GameSnapshot? snapshot,
    Object? inputLocked = _kUnset,
    Object? lastPlacedPosition = _kUnset,
    Object? lastRemovedPosition = _kUnset,
    int? matchDurationMs,
  }) {
    return GameState(
      snapshot: snapshot ?? this.snapshot,
      inputLocked: identical(inputLocked, _kUnset)
          ? this.inputLocked
          : inputLocked as bool,
      lastPlacedPosition: identical(lastPlacedPosition, _kUnset)
          ? this.lastPlacedPosition
          : lastPlacedPosition as Position?,
      lastRemovedPosition: identical(lastRemovedPosition, _kUnset)
          ? this.lastRemovedPosition
          : lastRemovedPosition as Position?,
      matchDurationMs: matchDurationMs ?? this.matchDurationMs,
    );
  }

  @override
  List<Object?> get props => [
    snapshot,
    inputLocked,
    lastPlacedPosition,
    lastRemovedPosition,
    matchDurationMs,
  ];
}
