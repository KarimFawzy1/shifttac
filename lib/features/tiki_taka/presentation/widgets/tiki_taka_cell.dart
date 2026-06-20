import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/tiki_cell.dart';
import '../../domain/services/player_image_url_validator.dart';
import 'player_avatar.dart';
import 'player_diagonal_name.dart';

/// One playable Tiki-Taka intersection showing a player image or diagonal name.
class TikiTakaCell extends StatelessWidget {
  const TikiTakaCell({
    super.key,
    required this.cell,
    required this.interactive,
    this.onTap,
    this.isActive = false,
  });

  final TikiCell cell;
  final bool interactive;
  final VoidCallback? onTap;
  final bool isActive;

  static const double _outerRadius = AppSpacing.radiusMd;
  static const bool _forceBoardAvatarLoadingForTest = false;

  @override
  Widget build(BuildContext context) {
    final filled = cell.isFilled;
    final label = filled ? cell.player!.displayName : null;
    final contentPadding = 2.w;
    final innerRadius = math.max(0.0, _outerRadius - contentPadding);

    return Semantics(
      label: filled
          ? 'Filled cell: $label'
          : 'Empty cell row ${cell.row + 1} column ${cell.col + 1}',
      button: !filled && interactive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: interactive ? onTap : null,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.borderRadiusMd,
              border: Border.all(
                color: isActive
                    ? AppColors.primary
                    : AppColors.outlineVariant.withValues(alpha: 0.7),
                width: isActive ? 2 : 1,
              ),
              boxShadow: filled
                  ? const [
                      BoxShadow(
                        color: Color(0x0F1D2330),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                        spreadRadius: -1,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: filled ? _filledContent(label!, innerRadius) : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filledContent(String displayName, double innerRadius) {
    if (isLoadablePlayerImageUrl(cell.player!.imageUrl)) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          if (!size.isFinite || size <= 0) {
            return const SizedBox.shrink();
          }

          return PlayerAvatar(
            imageUrl: cell.player!.imageUrl,
            playerName: displayName,
            size: size,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(innerRadius),
            forceLoadingFallback: _forceBoardAvatarLoadingForTest,
            loadingFallback: _AnimatedDiagonalLoadingName(
              displayName: displayName,
            ),
            unavailableFallback: PlayerDiagonalName(displayName: displayName),
          );
        },
      );
    }

    return PlayerDiagonalName(displayName: displayName);
  }
}

class _AnimatedDiagonalLoadingName extends StatefulWidget {
  const _AnimatedDiagonalLoadingName({required this.displayName});

  final String displayName;

  @override
  State<_AnimatedDiagonalLoadingName> createState() =>
      _AnimatedDiagonalLoadingNameState();
}

class _AnimatedDiagonalLoadingNameState
    extends State<_AnimatedDiagonalLoadingName>
    with SingleTickerProviderStateMixin {
  static const double _activeScale = 1.3;
  static const double _waveWidth = 1.8;

  late final AnimationController _controller;

  List<String> _characters = [];
  List<int> _animatableIndexes = [];

  @override
  void initState() {
    super.initState();
    _rebuildCharacters();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _AnimatedDiagonalLoadingName oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.displayName != widget.displayName) {
      _rebuildCharacters();
      _controller.forward(from: 0);
    }
  }

  void _rebuildCharacters() {
    _characters = widget.displayName.characters.toList();
    _animatableIndexes = [
      for (var i = 0; i < _characters.length; i++)
        if (_characters[i].trim().isNotEmpty) i,
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _scaleForLetter(int characterIndex, double progress) {
    final wavePosition = progress * (_animatableIndexes.length + _waveWidth);

    final letterOrder = _animatableIndexes.indexOf(characterIndex);
    if (letterOrder == -1) {
      return 1;
    }

    final distance = (wavePosition - letterOrder).abs();

    if (distance > _waveWidth) {
      return 1;
    }

    final influence = 1 - (distance / _waveWidth);
    final eased = Curves.easeInOut.transform(influence);

    return 1 + ((_activeScale - 1) * eased);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Transform.rotate(
          angle: -math.pi / 4,
          child: DefaultTextStyle(
            style: AppTextStyles.labelBold.copyWith(
              fontSize: 11.sp,
              color: AppColors.onSurface,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _characters.length; i++)
                      Transform.scale(
                        scale: _scaleForLetter(i, _controller.value),
                        child: Text(_characters[i]),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
