import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/home_action_card.dart';

/// Central hub body (`design.md` §HOME SCREEN, `css/HomeScreen.css`).
///
/// Rendered inside [MainShellScreen]; does not include scaffold or bottom nav.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: AppSpacing.stackLg.h),
          const _BrandBlock(),
          SizedBox(height: AppSpacing.stackLg.h),
          HomeActionCard(
            style: HomeActionCardStyle.heroPrimary,
            title: 'Play Local',
            subtitle: 'Play with a friend on the same device',
            iconAsset: IconConstant.multiplayer,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.game),
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          HomeActionCard(
            style: HomeActionCardStyle.disabledSecondary,
            title: 'Play Classic',
            subtitle: 'Traditional 3×3 — every mark stays on the board.',
            iconAsset: IconConstant.classicTicTacToe,
            iconWidth: 24.w,
            iconHeight: 24.h,
            badgeLabel: 'Coming Soon',
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          HomeActionCard(
            style: HomeActionCardStyle.disabledSecondary,
            title: 'Play vs AI',
            subtitle: 'Practice solo when it ships.',
            iconAsset: IconConstant.ai,
            iconWidth: 20.w,
            iconHeight: 20.h,
            badgeLabel: 'Coming Soon',
          ),
          SizedBox(height: AppSpacing.stackLg.h),
        ],
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 80.w,
          height: 80.w,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: DecoratedBox(
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
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: AppSpacing.borderRadiusMd,
                  child: Image.asset(
                    ImageConstant.homeIcon,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
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
