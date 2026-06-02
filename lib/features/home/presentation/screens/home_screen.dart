import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/morph_navigator.dart';
import '../../../../core/routing/morph_route_config.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../game/domain/models/game_mode.dart';
import '../../../game/domain/models/game_session_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scroll_view.dart';
import '../widgets/ai_settings_pills.dart';
import '../widgets/home_action_card.dart';

/// Central hub body (`design.md` §HOME SCREEN, `css/HomeScreen.css`).
///
/// Rendered inside [MainShellScreen]; does not include scaffold or bottom nav.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _playShiftTacMorphKey = GlobalKey();
  final GlobalKey _playClassicMorphKey = GlobalKey();
  final GlobalKey _playVsAiMorphKey = GlobalKey();

  static const MorphRouteConfig _heroMorphConfig = MorphRouteConfig(
    surfaceColor: AppColors.primary,
  );

  static const MorphRouteConfig _secondaryMorphConfig = MorphRouteConfig(
    surfaceColor: AppColors.surfaceContainerHighest,
  );

  Future<void> _openGameplay(
    BuildContext context, {
    required GlobalKey morphKey,
    Object? arguments,
    MorphRouteConfig config = _secondaryMorphConfig,
  }) {
    unawaited(AppAudioScope.read(context).playGameStart());
    return MorphNavigator.pushNamedFrom<void>(
      context: context,
      sourceKey: morphKey,
      routeName: AppRoutes.game,
      arguments: arguments,
      config: config,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return AppScrollView(
      child: Column(
        children: [
          SizedBox(height: AppSpacing.stackLg.h),
          const _BrandBlock(),
          SizedBox(height: AppSpacing.stackLg.h),
          HomeActionCard(
            morphKey: _playShiftTacMorphKey,
            style: HomeActionCardStyle.heroPrimary,
            title: 'Play ShiftTac',
            subtitle: 'Only 3 active marks — your oldest shifts off the board.',
            iconAsset: IconConstant.multiplayer,
            onTap: () {
              _openGameplay(
                context,
                morphKey: _playShiftTacMorphKey,
                config: _heroMorphConfig,
              );
            },
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          HomeActionCard(
            morphKey: _playClassicMorphKey,
            style: HomeActionCardStyle.secondary,
            title: 'Play Classic',
            subtitle: 'Traditional 3x3. Every mark stays on the board.',
            iconAsset: IconConstant.classicTicTacToe,
            iconWidth: 24.w,
            iconHeight: 24.h,
            onTap: () {
              _openGameplay(
                context,
                morphKey: _playClassicMorphKey,
                arguments: GameMode.classic,
              );
            },
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          HomeActionCard(
            morphKey: _playVsAiMorphKey,
            style: HomeActionCardStyle.secondary,
            title: 'VS AI',
            subtitle: 'Practice against the bot with your saved setup.',
            iconAsset: IconConstant.ai,
            iconWidth: 20.w,
            iconHeight: 20.h,
            topRightAccessory: AiSettingsPills(
              mode: settings.aiGameMode,
              difficulty: settings.aiDifficulty,
              onModeChanged: settings.setAiGameMode,
              onDifficultyChanged: settings.setAiDifficulty,
            ),
            onTap: () {
              final session = switch (settings.aiGameMode) {
                GameMode.classic => GameSessionConfig.classicAi(
                  settings.aiDifficulty,
                ),
                GameMode.shift => GameSessionConfig.shiftAi(
                  settings.aiDifficulty,
                ),
              };
              _openGameplay(
                context,
                morphKey: _playVsAiMorphKey,
                arguments: session,
              );
            },
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
