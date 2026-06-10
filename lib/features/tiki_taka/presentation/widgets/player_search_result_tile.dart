import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/tiki_player_search_result.dart';
import 'player_avatar.dart';

/// Single selectable row in the Tiki-Taka player search dialog.
class PlayerSearchResultTile extends StatefulWidget {
  const PlayerSearchResultTile({
    super.key,
    required this.player,
    required this.onTap,
    this.enabled = true,
  });

  final TikiPlayerSearchResult player;
  final VoidCallback onTap;
  final bool enabled;

  static const avatarLogicalSize = 40.0;

  @override
  State<PlayerSearchResultTile> createState() => _PlayerSearchResultTileState();
}

class _PlayerSearchResultTileState extends State<PlayerSearchResultTile>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final subtitle = _subtitleFor(widget.player);
    final avatarSize = PlayerSearchResultTile.avatarLogicalSize.w;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: subtitle == null
          ? widget.player.displayName
          : '${widget.player.displayName}, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                PlayerAvatar(
                  key: ValueKey(widget.player.imageUrl),
                  imageUrl: widget.player.imageUrl,
                  size: avatarSize,
                  borderRadius: BorderRadius.circular(avatarSize / 2),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.player.displayName,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: widget.enabled
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
                  color: widget.enabled
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
