import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Brand intro (`css/SplashScreen.css`, `design.md` §SPLASH SCREEN).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const double _tapBreatheScaleMin = 0.96;
  static const double _tapBreatheScaleMax = 1.0;

  late final AnimationController _breatheController;
  late final Animation<double> _breatheScale;
  late final DateTime _shownAt;
  bool _tapEnabled = false;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();
    _breatheController = AnimationController(
      vsync: this,
      duration: AppConstants.splashTapBreatheDuration,
    )..repeat(reverse: true);
    _breatheScale =
        Tween<double>(
          begin: _tapBreatheScaleMin,
          end: _tapBreatheScaleMax,
        ).animate(
          CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
        );
    _scheduleTapUnlock();
  }

  void _scheduleTapUnlock() {
    Future<void>.delayed(AppConstants.splashMinDisplayDuration, () {
      if (!mounted) return;
      setState(() => _tapEnabled = true);
    });
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!_tapEnabled) return;
    final elapsed = DateTime.now().difference(_shownAt);
    if (elapsed < AppConstants.splashMinDisplayDuration) return;

    Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SplashDecorativeBackground(),
            const _SplashBottomGradient(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerPadding.w,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SplashLogoArea(),
                      SizedBox(height: AppSpacing.stackLg.h),
                      const _SplashTypography(),
                      SizedBox(height: AppSpacing.stackLg.h),
                      _SplashTapCta(scale: _breatheScale),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashDecorativeBackground extends StatelessWidget {
  const _SplashDecorativeBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.03,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 22.35.w,
                top: 132.68.h,
                child: Transform.rotate(
                  angle: 12 * 3.141592653589793 / 180,
                  child: Text(
                    'X',
                    style: GoogleFonts.poppins(
                      fontSize: 120.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: AppColors.inkNavy,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 97.5.w,
                top: 221.h,
                child: _DecorativeORing(size: 128.w, borderWidth: 12.w),
              ),
              Positioned(
                right: 73.38.w,
                bottom: 191.69.h,
                child: Transform.rotate(
                  angle: -12 * 3.141592653589793 / 180,
                  child: _DecorativeORing(size: 160.w, borderWidth: 16.w),
                ),
              ),
              Positioned(
                right: 128.5.w,
                bottom: 92.65.h,
                child: Transform.rotate(
                  angle: -6 * 3.141592653589793 / 180,
                  child: Text(
                    'X',
                    style: GoogleFonts.poppins(
                      fontSize: 150.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: AppColors.inkNavy,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 19.5.w,
          top: 530.39.h,
          child: Opacity(
            opacity: 0.5,
            child: _DecorativeORing(size: 64.w, borderWidth: 6.w),
          ),
        ),
        Positioned(
          right: 74.14.w,
          top: 88.4.h,
          child: Opacity(
            opacity: 0.5,
            child: Transform.rotate(
              angle: 45 * 3.141592653589793 / 180,
              child: Text(
                'X',
                style: GoogleFonts.poppins(
                  fontSize: 80.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppColors.inkNavy,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DecorativeORing extends StatelessWidget {
  const _DecorativeORing({required this.size, required this.borderWidth});

  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.inkNavy, width: borderWidth),
      ),
    );
  }
}

class _SplashBottomGradient extends StatelessWidget {
  const _SplashBottomGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.warmIvory.withValues(alpha: 0),
            AppColors.warmIvory.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SplashLogoArea extends StatelessWidget {
  const _SplashLogoArea();

  @override
  Widget build(BuildContext context) {
    const logoSize = 280.0;

    return SizedBox(
      width: logoSize.w,
      height: logoSize.w,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: 0.6,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                width: logoSize.w,
                height: logoSize.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.softCoral.withValues(alpha: 0.2),
                      AppColors.teal.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22.r),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  offset: Offset(0, 8),
                  blurRadius: 5,
                ),
                BoxShadow(
                  color: Color(0x08000000),
                  offset: Offset(0, 20),
                  blurRadius: 13,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.r),
              child: Image.asset(
                ImageConstant.logo,
                width: logoSize.w,
                height: logoSize.w,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashTypography extends StatelessWidget {
  const _SplashTypography();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: AppTextStyles.displayLg.copyWith(
            color: AppColors.inkNavy,
            shadows: const [
              Shadow(
                color: Color(0x0D000000),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
        SizedBox(height: 7.9.h),
        Text(
          'The board never fills.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLg.copyWith(
            color: AppColors.outlineVariant,
            letterSpacing: 0.45,
          ),
        ),
      ],
    );
  }
}

class _SplashTapCta extends StatelessWidget {
  const _SplashTapCta({required this.scale});

  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.8,
      child: Column(
        children: [
          Text(
            'TAP TO START',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelBold.copyWith(
              color: AppColors.primary,
              letterSpacing: 2.8,
            ),
          ),
          SizedBox(height: 3.89.h),
          AnimatedBuilder(
            animation: scale,
            builder: (context, child) {
              return Transform.scale(scale: scale.value, child: child);
            },
            child: SvgPicture.asset(
              IconConstant.tap,
              width: 15.34.w,
              height: 18.23.h,
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
