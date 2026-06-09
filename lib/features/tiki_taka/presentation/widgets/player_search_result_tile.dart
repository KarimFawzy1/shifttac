import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/tiki_player_search_result.dart';
import 'player_avatar.dart';

/// Single selectable row in the Tiki-Taka player search dialog.
class PlayerSearchResultTile extends StatelessWidget {
  const PlayerSearchResultTile({
    super.key,
    required this.player,
    required this.onTap,
    this.enabled = true,
  });

  final TikiPlayerSearchResult player;
  final VoidCallback onTap;
  final bool enabled;

  static const _avatarSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitleFor(player);
    final avatarSize = _avatarSize.w;

    return Semantics(
      button: true,
      enabled: enabled,
      label: subtitle == null
          ? player.displayName
          : '${player.displayName}, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                PlayerAvatar(
                  imageUrl: player.imageUrl,
                  size: avatarSize,
                  borderRadius: BorderRadius.circular(avatarSize / 2),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.displayName,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: enabled
                              ? AppColors.onSurface
                              : AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled
                      ? AppColors.onSurfaceVariant
                      : AppColors.outlineVariant,
                  size: 22.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _subtitleFor(TikiPlayerSearchResult player) {
    final parts = <String>[
      if (player.position != null && player.position!.isNotEmpty)
        player.position!,
      if (player.nation != null && player.nation!.isNotEmpty) player.nation!,
    ];
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }
}
