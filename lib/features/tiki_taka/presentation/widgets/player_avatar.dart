import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/services/player_image_url_validator.dart';

/// Circular or rounded player face from a Commons URL, with person placeholder fallback.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticsLabel,
  });

  final String? imageUrl;
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedRadius = borderRadius ?? BorderRadius.circular(size / 2);

    if (!isLoadablePlayerImageUrl(imageUrl)) {
      _logFallback('invalid_url');
      return _PersonPlaceholder(
        size: size,
        borderRadius: resolvedRadius,
        semanticsLabel: semanticsLabel,
      );
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
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: fit,
            gaplessPlayback: true,
            excludeFromSemantics: semanticsLabel == null,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return _PersonPlaceholder(
                size: size,
                borderRadius: resolvedRadius,
                semanticsLabel: semanticsLabel,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              _logFallback('network_error');
              return _PersonPlaceholder(
                size: size,
                borderRadius: resolvedRadius,
                semanticsLabel: semanticsLabel,
              );
            },
          ),
        ),
      ),
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
