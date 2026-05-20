import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

void _playSettingsHaptic(BuildContext context) {
  if (!AppSettingsScope.read(context).vibrationEnabled) {
    return;
  }
  HapticFeedback.selectionClick();
}

/// White grouped card for a settings block (`css/SettingsScreen.css`).
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.6),
        borderRadius: AppSpacing.borderRadiusMd,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1D2330),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.unit.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.stackMd.w,
                AppSpacing.stackMd.h,
                AppSpacing.stackMd.w,
                AppSpacing.stackSm.h,
              ),
              child: Text(
                title.toUpperCase(),
                style: AppTextStyles.labelBold.copyWith(
                  color: AppColors.outline,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.stackMd.w,
                  ),
                  child: const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.surfaceContainerHighest,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Settings row with icon, title, optional subtitle, and trailing control.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    this.iconAsset,
    this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.enabled = true,
    this.onTap,
  });

  final String? iconAsset;
  final Widget? icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.stackMd.w,
        vertical: AppSpacing.stackMd.h,
      ),
      child: Row(
        children: [
          _SettingsIconBadge(iconAsset: iconAsset, icon: icon),
          SizedBox(width: AppSpacing.stackMd.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: enabled
                        ? AppColors.onSurface
                        : AppColors.onSurfaceVariant,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitle!,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: AppSpacing.stackSm.w),
          trailing,
        ],
      ),
    );

    if (onTap == null || !enabled) {
      return Opacity(opacity: enabled ? 1 : 0.75, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _playSettingsHaptic(context);
          onTap!();
        },
        borderRadius: AppSpacing.borderRadiusDefault,
        child: content,
      ),
    );
  }
}

class _SettingsIconBadge extends StatelessWidget {
  const _SettingsIconBadge({this.iconAsset, this.icon});

  final String? iconAsset;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceMist,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 40.w,
        height: 40.w,
        child: Center(
          child:
              icon ??
              (iconAsset != null
                  ? SvgPicture.asset(
                      iconAsset!,
                      width: 18.w,
                      height: 18.w,
                      colorFilter: const ColorFilter.mode(
                        AppColors.onSurface,
                        BlendMode.srcIn,
                      ),
                    )
                  : const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Pill switch matching `css/SettingsScreen.css` toggle placeholders.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _trackWidth = 48;
  static const double _trackHeight = 24;
  static const double _thumbSize = 16;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final trackColor = !enabled
        ? AppColors.surfaceContainerHighest
        : value
        ? AppColors.primary
        : AppColors.surfaceContainerHighest;

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? () {
                _playSettingsHaptic(context);
                onChanged!(!value);
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: _trackWidth.w,
          height: _trackHeight.h,
          padding: EdgeInsets.all(AppSpacing.unit.w),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: AppSpacing.borderRadiusFull,
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: _thumbSize.w,
            height: _thumbSize.w,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Disabled-row badge for post-MVP features.
class SettingsComingSoonBadge extends StatelessWidget {
  const SettingsComingSoonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
          'Coming Soon',
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.outline,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
