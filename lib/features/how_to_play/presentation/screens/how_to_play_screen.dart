import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../game/presentation/widgets/board_cell.dart';
import '../../../onboarding/presentation/widgets/mini_board_preview.dart';
import '../widgets/how_to_play_step.dart';

/// Visual rules reference (`design.md` §HOW TO PLAY SCREEN).
class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final ScrollController _scrollController = ScrollController();

  static final MiniBoardFrame _classicFrame = MiniBoardFrame(const [
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.xSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.oSolid,
  ]);

  static final MiniBoardFrame _fadedOldestFrame = MiniBoardFrame(const [
    BoardCellAppearance.empty,
    BoardCellAppearance.oSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.oSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.oFaded,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
  ]);

  static final MiniBoardFrame _winFrame = MiniBoardFrame(const [
    BoardCellAppearance.xSolid,
    BoardCellAppearance.oSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.oSolid,
    BoardCellAppearance.xSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.xSolid,
  ]);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _goHome() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      fullWidthHeader: true,
      safeAreaBottom: false,
      header: ColoredBox(
        color: AppColors.surface,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.containerPadding.w,
            vertical: AppSpacing.stackMd.h,
          ),
          child: ScreenHeader(
            leadingIconAsset: IconConstant.back,
            onLeadingPressed: _goHome,
            leadingSemanticLabel: 'Back to home',
            center: Text(
              'HOW TO PLAY',
              style: AppTextStyles.titleMd.copyWith(
                letterSpacing: 2.4,
                color: AppColors.onSurface,
              ),
            ),
            trailing: AppIconButton(
              iconAsset: IconConstant.restart,
              onPressed: _scrollToTop,
              semanticLabel: 'Back to top',
              transparentMaterial: true,
              iconColor: AppColors.outline,
              size: 32.w,
              iconSize: 16.w,
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.only(bottom: AppSpacing.stackLg.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learn ShiftTac',
                    style: AppTextStyles.displayLg.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.stackSm.h),
                  Text(
                    'Five quick visuals — no long rulebook.',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  SizedBox(height: AppSpacing.stackLg.h),
                  HowToPlayStep(
                    stepNumber: 1,
                    title: 'Classic board',
                    caption:
                        'A familiar 3×3 grid. Players take turns placing X and O.',
                    visual: HowToPlayVisualFrame(
                      child: MiniBoardPreview(
                        frame: _classicFrame,
                        style: MiniBoardStyle.classic,
                        size: 80.w,
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.stackMd.h + AppSpacing.stackMd.h),
                  HowToPlayStep(
                    stepNumber: 2,
                    title: '3 active marks only',
                    caption:
                        'Each player keeps only three marks on the board at once.',
                    visual: const HowToPlayVisualFrame(
                      child: _ThreeMarkLimitVisual(),
                    ),
                  ),
                  SizedBox(height: AppSpacing.stackMd.h + AppSpacing.stackMd.h),
                  HowToPlayStep(
                    stepNumber: 3,
                    title: 'Oldest mark fades',
                    caption:
                        'Your oldest mark fades so you know which one leaves next.',
                    visual: HowToPlayVisualFrame(
                      child: MiniBoardPreview(
                        frame: _fadedOldestFrame,
                        style: MiniBoardStyle.game,
                        size: 96.w,
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.stackMd.h + AppSpacing.stackMd.h),
                  HowToPlayStep(
                    stepNumber: 4,
                    title: '4th move removes oldest',
                    caption:
                        'Place a fourth mark and your oldest disappears.',
                    visual: const HowToPlayVisualFrame(
                      child: _ShiftRemovalVisual(),
                    ),
                  ),
                  SizedBox(height: AppSpacing.stackMd.h + AppSpacing.stackMd.h),
                  HowToPlayStep(
                    stepNumber: 5,
                    title: 'Get 3 in a row to win',
                    caption:
                        'Line up three in a row — horizontal, vertical, or diagonal.',
                    centerTitle: true,
                    visualSize: 192.w,
                    visual: HowToPlayVisualFrame(
                      size: 192.w,
                      child: _WinBoardVisual(frame: _winFrame),
                    ),
                  ),
                  SizedBox(height: AppSpacing.stackLg.h),
                  Center(
                    child: PrimaryButton(
                      label: 'Got it',
                      expand: false,
                      onPressed: _goHome,
                    ),
                  ),
                  SizedBox(height: AppSpacing.stackLg.h),
                ],
              ),
            ),
          ),
          const _HowToPlayBottomNav(),
        ],
      ),
    );
  }
}

class _ThreeMarkLimitVisual extends StatelessWidget {
  const _ThreeMarkLimitVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: EdgeInsets.only(
                right: index < 2 ? AppSpacing.unit.w : 0,
              ),
              child: SvgPicture.asset(
                IconConstant.x,
                width: 20.w,
                height: 20.w,
                colorFilter: const ColorFilter.mode(
                  AppColors.secondaryContainer,
                  BlendMode.srcIn,
                ),
              ),
            );
          }),
        ),
        SizedBox(height: AppSpacing.unit.h),
        Text(
          'MAX 3',
          style: AppTextStyles.labelBold.copyWith(
            color: AppColors.primary,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

class _ShiftRemovalVisual extends StatelessWidget {
  const _ShiftRemovalVisual();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.sync_alt_rounded,
      size: 48.w,
      color: AppColors.primary,
    );
  }
}

class _WinBoardVisual extends StatelessWidget {
  const _WinBoardVisual({required this.frame});

  final MiniBoardFrame frame;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        MiniBoardPreview(
          frame: frame,
          style: MiniBoardStyle.game,
          size: 128.w,
        ),
        IgnorePointer(
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 128.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.6),
                borderRadius: AppSpacing.borderRadiusFull,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8.r,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HowToPlayBottomNav extends StatelessWidget {
  const _HowToPlayBottomNav();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      elevation: 4,
      shadowColor: AppColors.inkNavy.withValues(alpha: 0.1),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusMd.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: AppSpacing.stackSm.h + AppSpacing.unit,
            horizontal: AppSpacing.stackLg.w,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavLink(
                iconAsset: IconConstant.play,
                label: 'Play',
                highlight: false,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.game),
              ),
              const _NavLink(
                iconAsset: IconConstant.rules,
                label: 'Rules',
                highlight: true,
                enabled: false,
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
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.iconAsset,
    required this.label,
    required this.highlight,
    this.onTap,
    this.enabled = true,
  });

  final String iconAsset;
  final String label;
  final bool highlight;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.outline;
    final bg = highlight
        ? AppColors.primaryContainer.withValues(alpha: 0.2)
        : Colors.transparent;

    return InkWell(
      onTap: !enabled || onTap == null
          ? null
          : () {
              Feedback.forTap(context);
              onTap!();
            },
      borderRadius: AppSpacing.borderRadiusMd,
      child: Opacity(
        opacity: highlight ? 1 : 0.7,
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
                  padding: EdgeInsets.all(highlight ? AppSpacing.stackSm.w : 0),
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
      ),
    );
  }
}
