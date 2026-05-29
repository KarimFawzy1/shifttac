import '../models/move.dart';
import 'game_snapshot.dart';

class GameEngineResult {
  const GameEngineResult({
    required this.snapshot,
    required this.moveAccepted,
    this.removedMove,
    this.placedMove,
  });

  final GameSnapshot snapshot;
  final bool moveAccepted;
  final Move? removedMove;
  final Move? placedMove;
}
