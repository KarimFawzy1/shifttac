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
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.borderRadius,
    this.semanticsLabel,
    this.unavailableFallback,
  });

  final String? imageUrl;
  final double size;
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

    if (!isLoadablePlayerImageUrl(imageUrl)) {
      _logFallback('invalid_url');
      return _fallbackWidget(resolvedRadius);
    }

    final url = imageUrl!.trim();

    return Semantics(
      label: semanticsLabel,
      image: true,
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: SizedBox(
          width: size,
          height: size,
          child: _PlayerNetworkImage(
            key: ValueKey(url),
            url: url,
            size: size,
            borderRadius: resolvedRadius,
            fit: fit,
            alignment: alignment,
            semanticsLabel: semanticsLabel,
            fallback: _fallbackWidget(resolvedRadius),
            onPermanentFailure: () => _logFallback('network_error'),
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

  void _logFallback(String reason) {
    if (!kDebugMode) {
      return;
    }
    final labelSuffix = semanticsLabel == null ? '' : ' label=$semanticsLabel';
    debugPrint('[PlayerAvatar] fallback$labelSuffix reason=$reason');
  }
}

enum _AvatarImageLoadState { loading, ready, failed }

class _PlayerNetworkImage extends StatefulWidget {
  const _PlayerNetworkImage({
    super.key,
    required this.url,
    required this.size,
    required this.borderRadius,
    required this.fit,
    required this.alignment,
    required this.fallback,
    required this.onPermanentFailure,
    this.semanticsLabel,
  });

  final String url;
  final double size;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Alignment alignment;
  final Widget fallback;
  final VoidCallback onPermanentFailure;
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

    if (_loadState == _AvatarImageLoadState.loading) {
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
      if (_loadState == _AvatarImageLoadState.loading) {
        _startLoad();
      }
    }
  }

  void _startLoad() {
    if (PlayerAvatarImageQueue.instance.isResolved(widget.url)) {
      if (mounted && _loadState != _AvatarImageLoadState.ready) {
        setState(() => _loadState = _AvatarImageLoadState.ready);
      }
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
          setState(() => _loadState = _AvatarImageLoadState.ready);
        })
        .catchError((_) {
          if (!mounted) {
            return;
          }
          widget.onPermanentFailure();
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
        widget.onPermanentFailure();
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
