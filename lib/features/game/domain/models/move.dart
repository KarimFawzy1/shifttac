import 'package:equatable/equatable.dart';

import 'player.dart';
import 'position.dart';

class Move extends Equatable {
  const Move({
    required this.player,
    required this.position,
    required this.turnIndex,
  });

  final Player player;
  final Position position;
  final int turnIndex;

  @override
  List<Object?> get props => [player, position, turnIndex];
}
