import '../../../../core/constants/app_constants.dart';

/// Wikimedia requires a descriptive User-Agent; missing it causes intermittent 403s.
final Map<String, String> kPlayerImageNetworkHeaders = {
  'User-Agent':
      '${AppConstants.appName}/${AppConstants.appVersionLabel} '
      '(player-images; +https://github.com/KarimFawzy1/shifttac)',
};

/// @deprecated Use [kPlayerImageNetworkHeaders].
Map<String, String> get playerImageNetworkHeaders => kPlayerImageNetworkHeaders;

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
