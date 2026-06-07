/// Local multiplayer rule set for a match.
///
/// Tiki-Taka 1P uses a dedicated `/tiki-taka` route — not a [GameMode] — so
/// Classic/Shift session config and X/O gameplay stay isolated.
enum GameMode {
  shift,
  classic,
}
