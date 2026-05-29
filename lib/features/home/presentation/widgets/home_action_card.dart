import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Large action surface for the home hub (`css/HomeScreen.css` hero / AI rows).
enum HomeActionCardStyle {
  /// Teal hero card (Play ShiftTac Multiplayer).
  heroPrimary,

  /// Muted disabled card (Play vs AI — Coming Soon).
  disabledSecondary,
}

class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.style,
    this.onTap,
    this.badgeLabel,
    this.iconWidth,
    this.iconHeight,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final HomeActionCardStyle style;
  final VoidCallback? onTap;
  final String? badgeLabel;
  final double? iconWidth;
  final double? iconHeight;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case HomeActionCardStyle.heroPrimary:
        assert(onTap != null, 'heroPrimary requires onTap');
        return _HeroPrimaryCard(
          title: title,
          subtitle: subtitle,
          iconAsset: iconAsset,
          iconWidth: iconWidth,
          iconHeight: iconHeight,
          onTap: onTap!,
        );
      case HomeActionCardStyle.disabledSecondary:
        return _DisabledSecondaryCard(
          title: title,
          subtitle: subtitle,
          iconAsset: iconAsset,
          iconWidth: iconWidth,
          iconHeight: iconHeight,
          badgeLabel: badgeLabel ?? 'Coming Soon',
        );
    }
  }
}

class _HeroPrimaryCard extends StatelessWidget {
  const _HeroPrimaryCard({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.onTap,
    this.iconWidth,
    this.iconHeight,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final VoidCallback onTap;
  final double? iconWidth;
  final double? iconHeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      elevation: AppSpacing.unit,
      shadowColor: AppColors.primary.withValues(alpha: 0.15),
      borderRadius: AppSpacing.borderRadiusMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Feedback.forTap(context);
          onTap();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -32.w,
              top: -32.h,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.3,
                  child: Container(
                    width: 128.r,
                    height: 128.r,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPressed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.containerPadding.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        iconAsset,
                        width: iconWidth ?? 26.w,
                        height: iconHeight ?? 19.h,
                        colorFilter: const ColorFilter.mode(
                          AppColors.onPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                      SizedBox(width: AppSpacing.stackSm.w),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.titleMd.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.stackSm.h),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisabledSecondaryCard extends StatelessWidget {
  const _DisabledSecondaryCard({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.badgeLabel,
    this.iconWidth,
    this.iconHeight,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final String badgeLabel;
  final double? iconWidth;
  final double? iconHeight;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: AppSpacing.borderRadiusMd,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D1D2330),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Color(0x081D2330),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.containerPadding.w,
            AppSpacing.containerPadding.w,
            AppSpacing.containerPadding.w,
            AppSpacing.containerPadding.h + 0.59,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    iconAsset,
                    width: iconWidth ?? 16.w,
                    height: iconHeight ?? 18.h,
                    colorFilter: const ColorFilter.mode(
                      AppColors.onSurfaceVariant,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: AppSpacing.stackSm.w),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: AppSpacing.borderRadiusFull,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.stackSm.w,
                        vertical: 3.5.h,
                      ),
                      child: Text(
                        badgeLabel,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.outline,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                subtitle,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
