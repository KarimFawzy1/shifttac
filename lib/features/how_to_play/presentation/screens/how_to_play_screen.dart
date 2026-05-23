import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_scroll_view.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../game/presentation/widgets/board_cell.dart';
import '../../../onboarding/presentation/widgets/mini_board_preview.dart';
import '../widgets/how_to_play_board_frames.dart';
import '../widgets/how_to_play_step.dart';

/// How to Play tab / standalone screen (`design.md` §HOW TO PLAY SCREEN).
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, this.standalone = false, this.onGoHome});

  final bool standalone;

  /// Switches the main shell to Home when embedded in [MainShellScreen].
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    final body = _HowToPlayBody(compact: standalone, onGoHome: onGoHome);

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
  const _HowToPlayBody({required this.compact, this.onGoHome});

  final bool compact;
  final VoidCallback? onGoHome;

  double get _boardSize => compact ? 168.w : 176.w;

  @override
  Widget build(BuildContext context) {
    var step = 0;

    return AppScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: AppSpacing.stackLg.h),
          Text(
            'How to Play',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMd.copyWith(color: AppColors.primary),
          ),
          SizedBox(height: AppSpacing.unit.h),
          Text(
            'Mastering the shift mechanic.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: AppSpacing.stackLg.h),
          if (!compact) ...[
            HowToPlayStep(
              stepNumber: ++step,
              title: 'The board',
              description:
                  'Classic 3×3 grid. Win with any row, column, or diagonal.',
              visual: MiniBoardPreview(
                frame: HowToPlayBoardFrames.classicStart,
                size: _boardSize,
              ),
              semanticLabel:
                  'Step $step. The board. Classic three by three grid.',
            ),
            SizedBox(height: AppSpacing.stackMd.h),
            HowToPlayStep(
              stepNumber: ++step,
              title: 'Three active marks',
              description:
                  'Each player may only have three marks on the board at once.',
              visual: MiniBoardPreview(
                frame: HowToPlayBoardFrames.threeActiveMarks,
                size: _boardSize,
              ),
              semanticLabel:
                  'Step $step. Three active marks. Maximum three per player.',
            ),
            SizedBox(height: AppSpacing.stackMd.h),
          ],
          HowToPlayStep(
            stepNumber: ++step,
            title: 'Shifts and faded marks',
            description: compact
                ? 'With three marks on the board, your oldest fades (👀) then '
                      'disappears when you place a fourth — that is a shift.'
                : 'When you already have three marks, your oldest fades. '
                      'Placing a fourth removes it and '
                      'places your new mark — we call that a shift.',
            visual: MiniBoardShiftAnimation(
              size: _boardSize,
              persistentCells: const {
                0: BoardCellAppearance.xSolid,
                3: BoardCellAppearance.xSolid,
                7: BoardCellAppearance.oSolid,
              },
              showIndicatorOnIndex: 1,
            ),
            semanticLabel:
                'Step $step. Shifts and faded marks. Oldest fades then '
                'disappears on fourth placement.',
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          HowToPlayStep(
            stepNumber: ++step,
            title: 'How to win',
            description:
                'First player to line up three active marks in a row wins.',
            visual: MiniBoardPreview(
              frame: HowToPlayBoardFrames.winRow,
              size: _boardSize,
              highlightIndex: 4,
            ),
            semanticLabel: 'Step $step. Three in a row wins the match.',
          ),
          SizedBox(height: AppSpacing.stackMd.h),
          const HowToPlayTip(),
          SizedBox(height: AppSpacing.stackMd.h),
          SecondaryButton(
            label: 'Replay tutorial',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.onboarding);
            },
          ),
          SizedBox(height: AppSpacing.stackMd.h),
        ],
      ),
    );
  }
}
