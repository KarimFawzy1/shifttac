/// Normalizes Transfermarkt player ids to `players.id` format.
String toTmPlayerId(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('tm:') ? trimmed : 'tm:$trimmed';
}
