import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../domain/models/tiki_game_status.dart';
import '../state/tiki_taka_cubit.dart';
import '../state/tiki_taka_state.dart';
import '../widgets/player_search_dialog.dart';
import '../widgets/tiki_board_frame.dart';
import '../widgets/tiki_taka_board.dart';
import '../widgets/tiki_taka_board_unavailable_view.dart';
import '../widgets/tiki_taka_completion_dialog.dart';
import '../widgets/tiki_taka_first_win_dialog.dart';
import '../widgets/tiki_taka_hud.dart';
import '../widgets/tiki_taka_lost_dialog.dart';
import '../widgets/tiki_taka_pause_sheet.dart';

/// Playable Tiki-Taka 1P board screen.
class TikiTakaGameplayScreen extends StatelessWidget {
  const TikiTakaGameplayScreen({
    super.key,
    this.cubit,
    this.autoLoadBoard = true,
  });

  /// When set (tests), this cubit is used instead of [TikiTakaCubit.production].
  final TikiTakaCubit? cubit;
  final bool autoLoadBoard;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: const _TikiTakaGameplayBody(),
      );
    }

    return BlocProvider(
      create: (_) => TikiTakaCubit.production(autoLoadBoard: autoLoadBoard),
      child: const _TikiTakaGameplayBody(),
    );
  }
}

class _TikiTakaGameplayBody extends StatelessWidget {
  const _TikiTakaGameplayBody();

  static final SystemUiOverlayStyle _systemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.warmIvory,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static bool _shouldShowOutcomeDialog(TikiGameStatus status) {
    return status == TikiGameStatus.firstWin ||
        status == TikiGameStatus.completed ||
        status == TikiGameStatus.lost;
  }

  static void _openPauseSheet(BuildContext context) {
    if (TikiTakaPauseSheet.isVisible ||
        TikiTakaFirstWinDialog.isVisible ||
        TikiTakaCompletionDialog.isVisible ||
        TikiTakaLostDialog.isVisible ||
        PlayerSearchDialog.isVisible) {
      return;
    }
    unawaited(TikiTakaPauseSheet.show(context));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TikiTakaCubit, TikiTakaState>(
          listenWhen: (previous, current) =>
              previous.activeCell != current.activeCell &&
              current.activeCell != null,
          listener: (context, state) {
            unawaited(PlayerSearchDialog.show(context));
          },
        ),
        BlocListener<TikiTakaCubit, TikiTakaState>(
          listenWhen: (previous, current) =>
              previous.status != current.status &&
              _shouldShowOutcomeDialog(current.status),
          listener: (context, state) {
            switch (state.status) {
              case TikiGameStatus.firstWin:
                unawaited(TikiTakaFirstWinDialog.show(context));
              case TikiGameStatus.completed:
                unawaited(TikiTakaCompletionDialog.show(context));
              case TikiGameStatus.lost:
                unawaited(TikiTakaLostDialog.show(context));
              case TikiGameStatus.initial ||
                  TikiGameStatus.loadingBoard ||
                  TikiGameStatus.ongoing ||
                  TikiGameStatus.continuing:
                break;
            }
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          _openPauseSheet(context);
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _systemUi,
          child: AppScaffold(
            fullWidthHeader: true,
            header: _TikiTakaHeader(
              onPause: () => _openPauseSheet(context),
            ),
            child: BlocBuilder<TikiTakaCubit, TikiTakaState>(
              buildWhen: (previous, current) =>
                  previous.status != current.status ||
                  previous.hearts != current.hearts ||
                  previous.elapsedMs != current.elapsedMs ||
                  previous.rowHeaders != current.rowHeaders ||
                  previous.columnHeaders != current.columnHeaders,
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: AppSpacing.stackMd.h),
                    TikiTakaHud(
                      hearts: state.hearts,
                      elapsedMs: state.elapsedMs,
                    ),
                    SizedBox(height: AppSpacing.stackMd.h),
                    if (state.status == TikiGameStatus.loadingBoard)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.rowHeaders.length == 3 &&
                        state.columnHeaders.length == 3)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: TikiBoardFrameLoader(
                                rowHeaders: state.rowHeaders,
                                columnHeaders: state.columnHeaders,
                                board: const TikiTakaBoard(),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: TikiTakaBoardUnavailableView(
                          onRetry: () => context.read<TikiTakaCubit>().loadBoard(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TikiTakaHeader extends StatelessWidget {
  const _TikiTakaHeader({required this.onPause});

  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.inkNavy.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: SizedBox(
        height: 64.h,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 16.h,
            horizontal: AppSpacing.containerPadding.w,
          ),
          child: Row(
            children: [
              AppIconButton(
                iconAsset: IconConstant.pause,
                semanticLabel: 'Pause',
                onPressed: onPause,
              ),
              Expanded(
                child: Text(
                  'Tiki-Taka',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleXs.copyWith(
                    color: AppColors.inkNavy,
                  ),
                ),
              ),
              SizedBox(width: 48.w),
            ],
          ),
        ),
      ),
    );
  }
}
