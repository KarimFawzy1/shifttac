/// Runtime guard for player avatar network loads (mirrors ETL Commons rules).
bool isLoadablePlayerImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    return false;
  }

  if (uri.scheme != 'https' || uri.host != 'commons.wikimedia.org') {
    return false;
  }

  return uri.path.contains('Special:FilePath');
}
