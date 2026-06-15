import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/services/player_avatar_image_provider.dart';
import '../../domain/services/player_avatar_image_queue.dart';
import '../../domain/services/player_image_url_validator.dart';

/// Circular or rounded player face from a Commons URL, with person placeholder fallback.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    this.playerName,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.borderRadius,
    this.semanticsLabel,
    this.unavailableFallback,
  });

  final String? imageUrl;
  final double size;

  /// Display name used for debug logs and accessibility when [semanticsLabel] is null.
  final String? playerName;
  final BoxFit fit;

  /// Crop anchor for [fit]. Wikidata portraits usually place the face near the top.
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final String? semanticsLabel;

  /// Shown while loading or when the network image fails (e.g. board cell offline).
  final Widget? unavailableFallback;

  @override
  Widget build(BuildContext context) {
    final resolvedRadius = borderRadius ?? BorderRadius.circular(size / 2);
    final resolvedPlayerName = _resolvedPlayerName;

    if (!isLoadablePlayerImageUrl(imageUrl)) {
      _logFallback(resolvedPlayerName, 'invalid_url');
      return _fallbackWidget(resolvedRadius);
    }

    final url = imageUrl!.trim();

    return Semantics(
      label: semanticsLabel ?? resolvedPlayerName,
      image: true,
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: SizedBox(
          width: size,
          height: size,
          child: _PlayerNetworkImage(
            key: ValueKey(url),
            url: url,
            playerName: resolvedPlayerName,
            size: size,
            borderRadius: resolvedRadius,
            fit: fit,
            alignment: alignment,
            semanticsLabel: semanticsLabel ?? resolvedPlayerName,
            fallback: _fallbackWidget(resolvedRadius),
            onPermanentFailure: (reason, error) =>
                _logFallback(resolvedPlayerName, reason, error: error),
            onLoaded: (source) => _logLoaded(resolvedPlayerName, url, source),
          ),
        ),
      ),
    );
  }

  Widget _fallbackWidget(BorderRadius resolvedRadius) {
    if (unavailableFallback != null) {
      return SizedBox(
        width: size,
        height: size,
        child: unavailableFallback,
      );
    }

    return _PersonPlaceholder(
      size: size,
      borderRadius: resolvedRadius,
      semanticsLabel: semanticsLabel,
    );
  }

  void _logFallback(String playerName, String reason, {Object? error}) {
    _PlayerAvatarDebug.logFallback(
      playerName: playerName,
      imageUrl: imageUrl,
      reason: reason,
      error: error,
    );
  }

  void _logLoaded(String playerName, String url, String source) {
    _PlayerAvatarDebug.logLoaded(
      playerName: playerName,
      imageUrl: url,
      source: source,
    );
  }

  String get _resolvedPlayerName =>
      playerName ?? semanticsLabel ?? 'unknown';
}

@visibleForTesting
class PlayerAvatarDebugLog {
  PlayerAvatarDebugLog._();

  static final Set<String> _logged = <String>{};

  static void logLoaded({
    required String playerName,
    required String imageUrl,
    required String source,
  }) {
    if (!kDebugMode) {
      return;
    }

    final key = 'loaded|$playerName|$imageUrl|$source';
    if (!_logged.add(key)) {
      return;
    }

    debugPrint(
      '[PlayerAvatar] loaded player=$playerName source=$source url=$imageUrl',
    );
  }

  static void logFallback({
    required String playerName,
    required String? imageUrl,
    required String reason,
    Object? error,
  }) {
    if (!kDebugMode) {
      return;
    }

    final key = 'fallback|$playerName|$reason|${imageUrl ?? ''}';
    if (!_logged.add(key)) {
      return;
    }

    final urlSuffix = imageUrl == null ? '' : ' url=$imageUrl';
    final errorSuffix = error == null ? '' : ' error=$error';
    debugPrint(
      '[PlayerAvatar] fallback player=$playerName reason=$reason$urlSuffix$errorSuffix',
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _logged.clear();
  }
}

class _PlayerAvatarDebug {
  _PlayerAvatarDebug._();

  static void logLoaded({
    required String playerName,
    required String imageUrl,
    required String source,
  }) {
    PlayerAvatarDebugLog.logLoaded(
      playerName: playerName,
      imageUrl: imageUrl,
      source: source,
    );
  }

  static void logFallback({
    required String playerName,
    required String? imageUrl,
    required String reason,
    Object? error,
  }) {
    PlayerAvatarDebugLog.logFallback(
      playerName: playerName,
      imageUrl: imageUrl,
      reason: reason,
      error: error,
    );
  }
}

enum _AvatarImageLoadState { loading, ready, failed }

class _PlayerNetworkImage extends StatefulWidget {
  const _PlayerNetworkImage({
    super.key,
    required this.url,
    required this.playerName,
    required this.size,
    required this.borderRadius,
    required this.fit,
    required this.alignment,
    required this.fallback,
    required this.onPermanentFailure,
    required this.onLoaded,
    this.semanticsLabel,
  });

  final String url;
  final String playerName;
  final double size;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Alignment alignment;
  final Widget fallback;
  final void Function(String reason, Object? error) onPermanentFailure;
  final void Function(String source) onLoaded;
  final String? semanticsLabel;

  @override
  State<_PlayerNetworkImage> createState() => _PlayerNetworkImageState();
}

class _PlayerNetworkImageState extends State<_PlayerNetworkImage> {
  late final ImageProvider<Object> _provider;
  late _AvatarImageLoadState _loadState;

  @override
  void initState() {
    super.initState();
    _provider = playerAvatarImageProvider(widget.url);
    _loadState = PlayerAvatarImageQueue.instance.isResolved(widget.url)
        ? _AvatarImageLoadState.ready
        : _AvatarImageLoadState.loading;

    if (_loadState == _AvatarImageLoadState.ready) {
      widget.onLoaded('cache');
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startLoad();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _PlayerNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _provider = playerAvatarImageProvider(widget.url);
      _loadState = PlayerAvatarImageQueue.instance.isResolved(widget.url)
          ? _AvatarImageLoadState.ready
          : _AvatarImageLoadState.loading;
      if (_loadState == _AvatarImageLoadState.ready) {
        widget.onLoaded('cache');
      } else {
        _startLoad();
      }
    }
  }

  void _markReady(String source) {
    if (_loadState == _AvatarImageLoadState.ready) {
      return;
    }
    widget.onLoaded(source);
    if (mounted) {
      setState(() => _loadState = _AvatarImageLoadState.ready);
    }
  }

  void _startLoad() {
    if (PlayerAvatarImageQueue.instance.isResolved(widget.url)) {
      _markReady('cache');
      return;
    }

    if (_loadState != _AvatarImageLoadState.loading) {
      setState(() => _loadState = _AvatarImageLoadState.loading);
    }

    final configuration = createLocalImageConfiguration(
      context,
      size: Size(widget.size, widget.size),
    );

    final requestedUrl = widget.url;
    final dedupeKey = PlayerAvatarImageQueue.instance.cacheKey(requestedUrl);

    PlayerAvatarImageQueue.instance
        .ensureCached(
          provider: _provider,
          dedupeKey: dedupeKey,
          configuration: configuration,
          url: requestedUrl,
        )
        .then((_) {
          if (!mounted || widget.url != requestedUrl) {
            return;
          }
          PlayerAvatarImageQueue.instance.markResolved(requestedUrl);
          _markReady('network');
        })
        .catchError((Object error) {
          if (!mounted) {
            return;
          }
          widget.onPermanentFailure('network_error', error);
          setState(() => _loadState = _AvatarImageLoadState.failed);
        });
  }

  Widget _loadingPlaceholder() {
    return _AvatarLoadingPlaceholder(
      size: widget.size,
      borderRadius: widget.borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadState == _AvatarImageLoadState.failed) {
      return widget.fallback;
    }

    if (_loadState == _AvatarImageLoadState.loading) {
      return _loadingPlaceholder();
    }

    return Image(
      image: _provider,
      width: widget.size,
      height: widget.size,
      fit: widget.fit,
      alignment: widget.alignment,
      gaplessPlayback: true,
      excludeFromSemantics: widget.semanticsLabel == null,
      errorBuilder: (context, error, stackTrace) {
        widget.onPermanentFailure('image_decode_error', error);
        return widget.fallback;
      },
    );
  }
}

class _AvatarLoadingPlaceholder extends StatelessWidget {
  const _AvatarLoadingPlaceholder({
    required this.size,
    required this.borderRadius,
  });

  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final indicatorSize = size * 0.42;

    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: AppColors.surfaceContainerHigh,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: SizedBox(
              width: indicatorSize,
              height: indicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonPlaceholder extends StatelessWidget {
  const _PersonPlaceholder({
    required this.size,
    required this.borderRadius,
    this.semanticsLabel,
  });

  final double size;
  final BorderRadius borderRadius;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.55;

    return Semantics(
      label: semanticsLabel,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          width: size,
          height: size,
          color: AppColors.surfaceContainerHigh,
          alignment: Alignment.center,
          child: Icon(
            Icons.person_rounded,
            size: iconSize,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
