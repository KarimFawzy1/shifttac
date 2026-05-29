class GameConstants {
  GameConstants._();

  static const int maxActiveMarks = 3;
  static const int boardRows = 3;
  static const int boardCols = 3;
  static const int boardCellCount = boardRows * boardCols;
  static const int inputLockMs = 140;
  static const int botMoveDelayMs = 600;
  static const int tapFeedbackMs = 140;
  static const int movePlacementMs = 200;
  static const int fadeRemovalMs = 250;
  static const int dialogEntranceMs = 280;
  static const double fadedMarkOpacity = 0.45;
}
