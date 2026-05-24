import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/settings/app_settings_defaults.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

void _playSettingsTap(BuildContext context, {bool playSound = true}) {
  if (playSound) {
    unawaited(AppAudioScope.read(context).playTap());
  }
  if (!AppSettingsScope.read(context).vibrationEnabled) {
    return;
  }
  HapticFeedback.selectionClick();
}

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
          _playSettingsTap(context);
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
                final nextValue = !value;
                _playSettingsTap(context);
                onChanged!(nextValue);
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

/// Volume slider styled like settings toggles (`css/SettingsScreen.css`).
///
/// Snaps to [AppSettingsDefaults.volumeStep] (5%) and fires haptic on each step.
class SettingsSlider extends StatefulWidget {
  const SettingsSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<SettingsSlider> createState() => _SettingsSliderState();
}

class _SettingsSliderState extends State<SettingsSlider> {
  int? _lastStepIndex;

  static int _stepIndex(double volume) =>
      (AppSettingsDefaults.snapVolume(volume) / AppSettingsDefaults.volumeStep)
          .round();

  void _syncStepIndex(double volume) {
    _lastStepIndex = _stepIndex(volume);
  }

  @override
  void initState() {
    super.initState();
    _syncStepIndex(widget.value);
  }

  @override
  void didUpdateWidget(covariant SettingsSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null) {
      _syncStepIndex(widget.value);
      return;
    }
    if ((oldWidget.value - widget.value).abs() >=
        AppSettingsDefaults.volumeStep) {
      _syncStepIndex(widget.value);
    }
  }

  void _handleChanged(double raw) {
    final stepped = AppSettingsDefaults.snapVolume(raw);
    final step = _stepIndex(stepped);
    if (step != _lastStepIndex) {
      _lastStepIndex = step;
      _playSettingsHaptic(context);
    }
    widget.onChanged?.call(stepped);
  }

  void _handleChangeEnd(double raw) {
    final stepped = AppSettingsDefaults.snapVolume(raw);
    _syncStepIndex(stepped);
    widget.onChangeEnd?.call(stepped);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final value = AppSettingsDefaults.snapVolume(widget.value);

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4.h,
        activeTrackColor: enabled
            ? AppColors.primary
            : AppColors.surfaceContainerHighest,
        inactiveTrackColor: AppColors.surfaceContainerHighest,
        thumbColor: AppColors.surfaceContainerLowest,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        disabledActiveTrackColor: AppColors.surfaceContainerHighest,
        disabledInactiveTrackColor: AppColors.surfaceContainerHighest,
        disabledThumbColor: AppColors.surfaceContainerLow,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16.r),
      ),
      child: Slider(
        value: value,
        min: 0,
        max: 1,
        onChanged: enabled ? _handleChanged : null,
        onChangeEnd: enabled ? _handleChangeEnd : null,
      ),
    );
  }
}

/// Settings row with title, subtitle, volume %, and an integrated slider.
class SettingsVolumeTile extends StatelessWidget {
  const SettingsVolumeTile({
    super.key,
    this.iconAsset,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.onPercentTap,
    this.playTapOnToggleOff = true,
  });

  final String? iconAsset;
  final Widget? icon;
  final String title;
  final String? subtitle;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final VoidCallback? onPercentTap;

  /// When false, [tap.wav] plays only when unmuting (toggle on), not when muting.
  final bool playTapOnToggleOff;

  @override
  Widget build(BuildContext context) {
    final steppedValue = AppSettingsDefaults.snapVolume(value);
    final isMuted = steppedValue == 0;
    final percentLabel = '${(steppedValue * 100).round()}%';

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.stackMd.w,
        vertical: AppSpacing.stackMd.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                        color: isMuted
                            ? AppColors.onSurfaceVariant
                            : AppColors.onSurface,
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
              Semantics(
                button: true,
                label: isMuted ? 'Unmute $title' : 'Mute $title',
                child: GestureDetector(
                  onTap: onPercentTap == null
                      ? null
                      : () {
                          final unmuting = isMuted;
                          if (unmuting && !playTapOnToggleOff) {
                            // SFX is still disabled until unmute; play tap after restore.
                            onPercentTap!();
                            _playSettingsTap(context);
                            return;
                          }
                          _playSettingsTap(
                            context,
                            playSound: unmuting || playTapOnToggleOff,
                          );
                          onPercentTap!();
                        },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.unit.w,
                      vertical: AppSpacing.unit.h,
                    ),
                    child: Text(
                      percentLabel,
                      style: AppTextStyles.titleXs.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isMuted
                            ? AppColors.outline
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.stackSm.h),
          SettingsSlider(
            value: steppedValue,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
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
