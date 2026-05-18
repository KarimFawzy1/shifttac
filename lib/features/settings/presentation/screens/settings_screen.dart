import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/screen_header.dart';

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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: AppSpacing.stackLg.h),
          Text(
            'Settings',
            style: AppTextStyles.titleMd.copyWith(color: AppColors.onSurface),
          ),
          SizedBox(height: AppSpacing.stackLg.h),
          const _SettingsSection(
            title: 'Theme',
            children: [
              _SettingsTile(label: 'Light'),
              _SettingsTile(label: 'Dark'),
            ],
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          const _SettingsSection(
            title: 'Audio',
            children: [
              _SettingsTile(label: 'Sound effects'),
              _SettingsTile(label: 'Music'),
            ],
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          const _SettingsSection(
            title: 'Gameplay',
            children: [_SettingsTile(label: 'Vibration')],
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          const _SettingsSection(
            title: 'About',
            children: [
              _SettingsTile(label: 'Version ${AppConstants.appVersionLabel}'),
              _SettingsTile(label: 'ShiftTac · AllTerrainTech'),
            ],
          ),
          SizedBox(height: AppSpacing.stackLg.h),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppTextStyles.labelBold.copyWith(color: AppColors.outline),
        ),
        SizedBox(height: AppSpacing.stackSm.h),
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) SizedBox(height: AppSpacing.unit.h),
        ],
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppSpacing.borderRadiusMd,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.stackMd.w,
          vertical: AppSpacing.stackMd.h,
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
        ),
      ),
    );
  }
}
