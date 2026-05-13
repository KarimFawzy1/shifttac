enum Player {
  x,
  o;

  Player get opponent => this == Player.x ? Player.o : Player.x;
}
