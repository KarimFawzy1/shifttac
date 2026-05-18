import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../game/presentation/widgets/board_cell.dart';
import '../../../onboarding/presentation/widgets/mini_board_preview.dart';

/// How to Play tab / standalone screen (`design.md` §HOW TO PLAY SCREEN).
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final body = const _HowToPlayBody();

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

class _HowToPlayBody extends StatelessWidget {
  const _HowToPlayBody();

  static const _steps = [
    'Classic 3×3 board — same winning lines as tic-tac-toe.',
    'Each player keeps only 3 active marks on the board.',
    'When you place a 4th mark, your oldest mark fades away.',
    'Plan shifts around disappearing marks to get three in a row.',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: AppSpacing.stackLg.h),
          Text(
            'How to Play',
            style: AppTextStyles.titleMd.copyWith(color: AppColors.onSurface),
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          Center(
            child: MiniBoardPreview(
              frame: MiniBoardFrame(const [
                BoardCellAppearance.xSolid,
                BoardCellAppearance.empty,
                BoardCellAppearance.oSolid,
                BoardCellAppearance.empty,
                BoardCellAppearance.xSolid,
                BoardCellAppearance.empty,
                BoardCellAppearance.oSolid,
                BoardCellAppearance.empty,
                BoardCellAppearance.empty,
              ]),
              size: 200.w,
            ),
          ),
          SizedBox(height: AppSpacing.stackLg.h),
          for (var i = 0; i < _steps.length; i++) ...[
            _StepRow(index: i + 1, text: _steps[i]),
            if (i < _steps.length - 1) SizedBox(height: AppSpacing.stackMd.h),
          ],
          SizedBox(height: AppSpacing.stackLg.h),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.2),
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.stackSm.w,
              vertical: AppSpacing.unit.h,
            ),
            child: Text(
              '$index',
              style: AppTextStyles.labelBold.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.stackMd.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
