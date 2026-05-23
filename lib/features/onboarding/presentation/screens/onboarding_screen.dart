import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/launch/app_launch_prefs.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../game/presentation/widgets/board_cell.dart';
import '../widgets/mini_board_preview.dart';
import '../widgets/onboarding_page.dart';

/// First-launch tutorial (`design.md` §ONBOARDING SCREEN 1–3).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pageCount = 3;

  final PageController _pageController = PageController();
  final AppLaunchPrefs _launchPrefs = AppLaunchPrefs();
  int _currentPage = 0;

  static final MiniBoardFrame _classicFrame = MiniBoardFrame(const [
    BoardCellAppearance.xSolid,
    BoardCellAppearance.xSolid,
    BoardCellAppearance.oSolid,
    BoardCellAppearance.xSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.oSolid,
    BoardCellAppearance.oSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
  ]);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeAndGoHome() async {
    await _launchPrefs.markOnboardingCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  void _onNext() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      return;
    }
    _completeAndGoHome();
  }

  void _onBack() {
    if (_currentPage == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pageCount - 1;
    final isFirstPage = _currentPage == 0;

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: SvgPicture.asset(
                IconConstant.xoOnboardingBackground,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    children: [
                      OnboardingPage(
                        title: 'Looks familiar?',
                        description: 'It starts like classic ShiftTac…',
                        visual: MiniBoardPreview(
                          frame: _classicFrame,
                          size: 302.w,
                        ),
                      ),
                      OnboardingPage(
                        title: 'Only 3 marks stay active',
                        description:
                            'Your oldest move disappears when you place a new one.',
                        visual: MiniBoardShiftAnimation.tutorial(size: 302.w),
                      ),
                      OnboardingPage(
                        title: 'Watch the faded mark',
                        description:
                            'The faded mark shows which move disappears next.',
                        visual: MiniBoardShiftAnimation.tutorialO(size: 302.w),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.containerPadding.w,
                    AppSpacing.stackLg.h,
                    AppSpacing.containerPadding.w,
                    AppSpacing.stackLg.h,
                  ),
                  child: Column(
                    children: [
                      OnboardingPageIndicator(
                        pageCount: _pageCount,
                        currentIndex: _currentPage,
                      ),
                      SizedBox(height: AppSpacing.stackLg.h),
                      if (isFirstPage)
                        PrimaryButton(label: 'Next', onPressed: _onNext)
                      else if (isLastPage)
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                label: 'Back',
                                onPressed: _onBack,
                                expand: false,
                              ),
                            ),
                            SizedBox(width: AppSpacing.stackMd.w),
                            Expanded(
                              child: PrimaryButton(
                                label: 'Start Playing',
                                onPressed: _completeAndGoHome,
                                expand: false,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                label: 'Back',
                                onPressed: _onBack,
                                expand: false,
                              ),
                            ),
                            SizedBox(width: AppSpacing.stackMd.w),
                            Expanded(
                              child: PrimaryButton(
                                label: 'Next',
                                onPressed: _onNext,
                                expand: false,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
