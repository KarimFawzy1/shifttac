import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/tiki_cell.dart';
import '../../domain/services/player_image_url_validator.dart';
import 'player_avatar.dart';

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

  @override
  Widget build(BuildContext context) {
    final filled = cell.isFilled;
    final label = filled ? cell.player!.displayName : null;

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
              padding: EdgeInsets.all(6.w),
              child: filled ? _filledContent(label!) : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filledContent(String displayName) {
    if (isLoadablePlayerImageUrl(cell.player!.imageUrl)) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          if (!size.isFinite || size <= 0) {
            return const SizedBox.shrink();
          }

          return PlayerAvatar(
            imageUrl: cell.player!.imageUrl,
            size: size,
            fit: BoxFit.cover,
            borderRadius: AppSpacing.borderRadiusMd,
          );
        },
      );
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Transform.rotate(
          angle: -math.pi / 4,
          child: Text(
            displayName,
            style: AppTextStyles.labelBold.copyWith(
              fontSize: 11.sp,
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
