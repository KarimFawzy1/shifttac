import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/modal_backdrop.dart';
import '../../../../core/widgets/primary_button.dart';
import '../state/game_cubit.dart';

/// Pause menu bottom sheet from `css/PauseMenu.css` (tokens only).
class PauseBottomSheet extends StatelessWidget {
  const PauseBottomSheet._({
    required this.cubit,
    required this.navigator,
    required this.sheetContext,
    required this.resumeTimerOnClose,
    required this.routeAnimation,
  });

  final GameCubit cubit;
  final NavigatorState navigator;
  final BuildContext sheetContext;
  final ValueNotifier<bool> resumeTimerOnClose;
  final Animation<double> routeAnimation;

  static const Duration _animationDuration = Duration(milliseconds: 300);

  static bool _isVisible = false;

  static bool get isVisible => _isVisible;

  static Future<void> show(BuildContext context) {
    if (_isVisible) {
      return Future<void>.value();
    }

    final cubit = context.read<GameCubit>();
    final navigator = Navigator.of(context);
    final resumeTimerOnClose = ValueNotifier(true);
    final localizations = MaterialLocalizations.of(context);

    cubit.pauseMatch();
    cubit.clearPauseSheetRequestForBackground();
    _isVisible = true;
    unawaited(AppAudioScope.read(context).playSwipe());
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: localizations.modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: _animationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return PauseBottomSheet._(
          cubit: cubit,
          navigator: navigator,
          sheetContext: dialogContext,
          resumeTimerOnClose: resumeTimerOnClose,
          routeAnimation: animation,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ).whenComplete(() {
      _isVisible = false;
      if (resumeTimerOnClose.value && !cubit.isClosed) {
        cubit.resumeMatch();
      }
      resumeTimerOnClose.dispose();
    });
  }

  void _popSheet({bool resumeTimer = true, bool playSwipeSfx = true}) {
    if (playSwipeSfx) {
      unawaited(AppAudioScope.read(sheetContext).playSwipe());
    }
    resumeTimerOnClose.value = resumeTimer;
    Navigator.of(sheetContext).pop();
  }

  void _goHome() {
    _popSheet(resumeTimer: false);
    navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  void _openRoute(String routeName) {
    _popSheet(resumeTimer: false);
    navigator.pushNamed(routeName).whenComplete(() {
      if (!cubit.isClosed) {
        cubit.resumeMatch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final backdropCurve = CurvedAnimation(
      parent: routeAnimation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    final sheetCurve = CurvedAnimation(
      parent: routeAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(sheetCurve);

    final sheet = _DraggablePauseSheet(
      onDismiss: () => _popSheet(),
      onResume: () => _popSheet(),
      onRestart: () {
        unawaited(AppAudioScope.read(sheetContext).playRestart());
        _popSheet(resumeTimer: false, playSwipeSfx: false);
        cubit.restart();
      },
      onHowToPlay: () => _openRoute(AppRoutes.howToPlay),
      onSettings: () => _openRoute(AppRoutes.settings),
      onExitHome: _goHome,
    );

    return AnimatedBuilder(
      animation: backdropCurve,
      builder: (context, _) {
        final t = backdropCurve.value;
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ModalBackdrop(
                  progress: t,
                  onTap: () => _popSheet(),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(position: sheetSlide, child: sheet),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Drag down on the handle or title to dismiss.
class _DraggablePauseSheet extends StatefulWidget {
  const _DraggablePauseSheet({
    required this.onDismiss,
    required this.onResume,
    required this.onRestart,
    required this.onHowToPlay,
    required this.onSettings,
    required this.onExitHome,
  });

  final VoidCallback onDismiss;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHowToPlay;
  final VoidCallback onSettings;
  final VoidCallback onExitHome;

  static const double _dismissDragThreshold = 96;
  static const double _dismissFlingVelocity = 500;

  @override
  State<_DraggablePauseSheet> createState() => _DraggablePauseSheetState();
}

class _DraggablePauseSheetState extends State<_DraggablePauseSheet>
    with SingleTickerProviderStateMixin {
  static const Duration _snapBackDuration = Duration(milliseconds: 200);

  late final AnimationController _snapBackController;

  double _dragExtent = 0;
  double _snapBackStart = 0;

  @override
  void initState() {
    super.initState();
    _snapBackController =
        AnimationController(vsync: this, duration: _snapBackDuration)
          ..addListener(_onSnapBackTick)
          ..addStatusListener(_onSnapBackStatus);
  }

  void _onSnapBackStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _dragExtent = 0);
    }
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    super.dispose();
  }

  void _onSnapBackTick() {
    if (!_snapBackController.isAnimating) {
      return;
    }
    final t = Curves.easeOutCubic.transform(_snapBackController.value);
    setState(() => _dragExtent = _snapBackStart * (1 - t));
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _snapBackController.stop();
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dy).clamp(
        0.0,
        double.infinity,
      );
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragExtent >= _DraggablePauseSheet._dismissDragThreshold ||
        velocity >= _DraggablePauseSheet._dismissFlingVelocity) {
      widget.onDismiss();
      return;
    }
    if (_dragExtent <= 0) {
      return;
    }
    _animateSnapBack();
  }

  void _animateSnapBack() {
    _snapBackStart = _dragExtent;
    _snapBackController
      ..stop()
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, _dragExtent),
      child: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: _PauseSheetContent(
          onResume: widget.onResume,
          onRestart: widget.onRestart,
          onHowToPlay: widget.onHowToPlay,
          onSettings: widget.onSettings,
          onExitHome: widget.onExitHome,
        ),
      ),
    );
  }
}

class _PauseSheetContent extends StatelessWidget {
  const _PauseSheetContent({
    required this.onResume,
    required this.onRestart,
    required this.onHowToPlay,
    required this.onSettings,
    required this.onExitHome,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHowToPlay;
  final VoidCallback onSettings;
  final VoidCallback onExitHome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.stackMd.w,
        right: AppSpacing.stackMd.w,
        bottom: AppSpacing.stackMd.h,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceMist,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl.r),
            bottom: Radius.circular(AppSpacing.radiusMd.r),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A1D2330),
              offset: Offset(0, -8),
              blurRadius: 32,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.containerPadding.w,
            AppSpacing.stackMd.h,
            AppSpacing.containerPadding.w,
            AppSpacing.containerPadding.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Drag down to close',
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.stackSm.h),
                  child: Container(
                    width: 48.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: AppSpacing.borderRadiusFull,
                    ),
                  ),
                ),
              ),
              Text(
                'Paused',
                style: AppTextStyles.titleMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              PrimaryButton(
                label: 'Resume',
                leading: SvgPicture.asset(
                  IconConstant.resume,
                  width: 14.w,
                  height: 14.w,
                  colorFilter: const ColorFilter.mode(
                    AppColors.onPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: onResume,
              ),
              SizedBox(height: AppSpacing.gridGutter.h),
              _MenuTile(
                iconAsset: IconConstant.restart,
                label: 'Restart Match',
                onTap: onRestart,
              ),
              SizedBox(height: AppSpacing.gridGutter.h),
              _MenuTile(
                iconAsset: IconConstant.howToPlay,
                label: 'How to Play',
                onTap: onHowToPlay,
              ),
              SizedBox(height: AppSpacing.gridGutter.h),
              _MenuTile(
                iconAsset: IconConstant.settings,
                label: 'Settings',
                onTap: onSettings,
              ),
              SizedBox(height: AppSpacing.gridGutter.h),
              _MenuTile(
                iconAsset: IconConstant.logout,
                label: 'Exit to Home',
                destructive: true,
                onTap: onExitHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final borderColor = destructive
        ? AppColors.errorContainer
        : AppColors.surfaceContainerHighest;
    final titleColor = destructive
        ? AppColors.error
        : AppColors.onSurfaceVariant;
    final iconBg = destructive
        ? AppColors.errorContainer.withValues(alpha: 0.5)
        : AppColors.surfaceContainerHighest;
    final iconTint = destructive ? AppColors.error : AppColors.onSurfaceVariant;

    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLg,
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Feedback.forTap(context);
          onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.containerPadding.w,
            vertical: AppSpacing.stackMd.h,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(10.w),
                  child: SvgPicture.asset(
                    iconAsset,
                    width: 20.w,
                    height: 20.w,
                    colorFilter: ColorFilter.mode(iconTint, BlendMode.srcIn),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.stackMd.w),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.headlineSm.copyWith(color: titleColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
