import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/infinity_logo.dart';
import '../widgets/home_action_card.dart';

/// Central hub (`design.md` §HOME SCREEN, `css/HomeScreen.css`).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: AppSpacing.stackLg.h),
                  _BrandBlock(),
                  SizedBox(height: AppSpacing.stackLg.h),
                  HomeActionCard(
                    style: HomeActionCardStyle.heroPrimary,
                    title: 'Play Local Multiplayer',
                    subtitle: 'Play with a friend on the same device',
                    iconAsset: IconConstant.play,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.game),
                  ),
                  SizedBox(height: AppSpacing.stackMd.h),
                  HomeActionCard(
                    style: HomeActionCardStyle.disabledSecondary,
                    title: 'Play vs AI',
                    subtitle: 'Practice solo when it ships.',
                    iconAsset: IconConstant.ai,
                    badgeLabel: 'Coming Soon',
                  ),
                  SizedBox(height: AppSpacing.stackLg.h),
                ],
              ),
            ),
          ),
          const _SecondaryNavBar(),
          SizedBox(height: AppSpacing.stackMd.h),
          _Footer(),
          SizedBox(height: AppSpacing.stackSm.h),
        ],
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceMist,
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
          child: SizedBox(
            width: 80.w,
            height: 80.w,
            child: Center(
              child: InfinityLogo(size: 44.r),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.stackMd.h),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: AppTextStyles.displayLg.copyWith(color: AppColors.onSurface),
        ),
        SizedBox(height: AppSpacing.stackSm.h),
        Text(
          'Offline Multiplayer Strategy Game',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SecondaryNavBar extends StatelessWidget {
  const _SecondaryNavBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      elevation: 1,
      shadowColor: AppColors.inkNavy.withValues(alpha: 0.05),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusMd.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppSpacing.stackSm.h + AppSpacing.unit,
          horizontal: AppSpacing.stackLg.w,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavLink(
              iconAsset: IconConstant.rules,
              label: 'How to Play',
              highlight: false,
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.howToPlay),
            ),
            _NavLink(
              iconAsset: IconConstant.settings,
              label: 'Settings',
              highlight: false,
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.iconAsset,
    required this.label,
    required this.highlight,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.outline;
    final bg = highlight
        ? AppColors.primaryContainer.withValues(alpha: 0.2)
        : Colors.transparent;

    return InkWell(
      onTap: () {
        Feedback.forTap(context);
        onTap();
      },
      borderRadius: AppSpacing.borderRadiusMd,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.stackMd.w,
          vertical: AppSpacing.unit.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.unit.w + AppSpacing.unit),
                child: SvgPicture.asset(
                  iconAsset,
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.unit.h),
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Version ${AppConstants.appVersionLabel}',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
        ),
        SizedBox(height: AppSpacing.unit.h),
        Text(
          'ShiftTac · AllTerrainTech',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
        ),
      ],
    );
  }
}
