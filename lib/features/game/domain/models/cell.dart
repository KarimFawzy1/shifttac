import 'package:equatable/equatable.dart';

import 'player.dart';
import 'position.dart';

class Cell extends Equatable {
  const Cell({required this.position, this.owner, this.isFadedOldest = false});

  final Position position;
  final Player? owner;
  final bool isFadedOldest;

  static const Object _unset = Object();

  Cell copyWith({
    Position? position,
    Object? owner = _unset,
    bool? isFadedOldest,
  }) {
    return Cell(
      position: position ?? this.position,
      owner: owner == _unset ? this.owner : owner as Player?,
      isFadedOldest: isFadedOldest ?? this.isFadedOldest,
    );
  }

  @override
  List<Object?> get props => [position, owner, isFadedOldest];
}
