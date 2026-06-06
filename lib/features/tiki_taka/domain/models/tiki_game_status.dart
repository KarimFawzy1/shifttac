/// Lifecycle status for a 1 Player Tiki-Taka match.
enum TikiGameStatus {
  initial,
  loadingBoard,
  ongoing,
  firstWin,
  continuing,
  completed,
  lost,
}
