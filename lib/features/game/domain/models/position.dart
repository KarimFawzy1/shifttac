import 'package:equatable/equatable.dart';

class Position extends Equatable {
  const Position({required this.row, required this.col})
    : assert(row >= 0 && row <= 2, 'row must be within 0..2'),
      assert(col >= 0 && col <= 2, 'col must be within 0..2');

  factory Position.fromIndex(int index) {
    assert(index >= 0 && index <= 8, 'index must be within 0..8');
    return Position(row: index ~/ 3, col: index % 3);
  }

  final int row;
  final int col;

  int get index => row * 3 + col;

  @override
  List<Object?> get props => [row, col];
}
