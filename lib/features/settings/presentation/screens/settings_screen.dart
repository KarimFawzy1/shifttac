import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../widgets/settings_tile.dart';

/// Settings tab / standalone screen (`design.md` §SETTINGS SCREEN).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final body = const _SettingsBody();

    if (!standalone) {
      return body;
    }

    return AppScaffold(
      header: ScreenHeader(
        leadingIconAsset: IconConstant.back,
        onLeadingPressed: () => Navigator.of(context).pop(),
        leadingSemanticLabel: 'Back',
      ),
      child: body,
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppSpacing.stackLg.h),
              Text(
                'Settings',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMd.copyWith(
                  color: AppColors.primary,
                  fontSize: 32.sp,
                  height: 38 / 32,
                  letterSpacing: -0.64,
                ),
              ),
              SizedBox(height: AppSpacing.unit.h + 0.59.h),
              Text(
                'Customize your experience',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.outline),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              SettingsSection(
                title: 'Theme',
                children: [
                  SettingsTile(
                    iconAsset: IconConstant.dark,
                    title: 'Dark mode',
                    subtitle: 'Easier on the eyes at night',
                    enabled: false,
                    trailing: const SettingsSwitch(
                      value: false,
                      onChanged: null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.stackMd.h),
              SettingsSection(
                title: 'Audio',
                children: [
                  SettingsTile(
                    iconAsset: IconConstant.sound,
                    title: 'Sound effects',
                    subtitle: 'Placement, removal, and win sounds',
                    trailing: SettingsSwitch(
                      value: settings.soundEffectsEnabled,
                      onChanged: (value) =>
                          settings.soundEffectsEnabled = value,
                    ),
                  ),
                  SettingsTile(
                    iconAsset: IconConstant.music,
                    title: 'Music',
                    subtitle: 'Background music',
                    trailing: SettingsSwitch(
                      value: settings.musicEnabled,
                      onChanged: (value) => settings.musicEnabled = value,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.stackMd.h),
              SettingsSection(
                title: 'Gameplay',
                children: [
                  SettingsTile(
                    iconAsset: IconConstant.haptic,
                    title: 'Vibration',
                    subtitle: 'Haptic feedback on taps',
                    trailing: SettingsSwitch(
                      value: settings.vibrationEnabled,
                      onChanged: (value) => settings.vibrationEnabled = value,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.stackMd.h),
              SettingsSection(
                title: 'About',
                children: [
                  SettingsTile(
                    iconAsset: IconConstant.version,
                    title: 'Version',
                    trailing: Text(
                      AppConstants.appVersionLabel,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                  ),
                  SettingsTile(
                    icon: SvgPicture.asset(
                      IconConstant.credits,
                      width: 20.w,
                      colorFilter: const ColorFilter.mode(
                        AppColors.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                    title: 'Credits',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'AllTerrainTech',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                        SizedBox(width: AppSpacing.stackSm.w),
                        Text(
                          '›',
                          style: AppTextStyles.bodyLg.copyWith(
                            color: AppColors.outline,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.stackLg.h),
            ],
          ),
        );
      },
    );
  }
}
