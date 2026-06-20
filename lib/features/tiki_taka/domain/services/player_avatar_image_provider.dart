import 'package:flutter/painting.dart';

import 'player_image_url_validator.dart';

/// Decode size for all player avatars — matches Commons `?width=128` in ETL URLs.
///
/// One size per URL lets search thumbnails and board cells share a single
/// [ImageCache] entry instead of re-downloading when the player is selected.
const int kPlayerAvatarDecodeSize = 128;

final Map<String, ImageProvider<Object>> _providersByUrl = {};

/// Shared [ImageProvider] for avatars — one instance per URL for stable cache keys.
ImageProvider<Object> playerAvatarImageProvider(String url) {
  final trimmed = url.trim();
  return _providersByUrl.putIfAbsent(
    trimmed,
    () => ResizeImage(
      NetworkImage(trimmed, headers: kPlayerImageNetworkHeaders),
      width: kPlayerAvatarDecodeSize,
      height: kPlayerAvatarDecodeSize,
    ),
  );
}

void clearPlayerAvatarImageProviderCache() {
  _providersByUrl.clear();
}
