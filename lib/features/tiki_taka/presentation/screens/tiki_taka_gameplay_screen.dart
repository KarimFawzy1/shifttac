import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../game/presentation/widgets/exit_game_dialog.dart';
import '../../domain/models/tiki_game_status.dart';
import '../state/tiki_taka_cubit.dart';
import '../state/tiki_taka_state.dart';
import '../widgets/tiki_taka_warmup_layer.dart';
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

  static bool _isActiveMatch(TikiGameStatus status) {
    return switch (status) {
      TikiGameStatus.ongoing ||
      TikiGameStatus.continuing ||
      TikiGameStatus.firstWin => true,
      TikiGameStatus.initial ||
      TikiGameStatus.loadingBoard ||
      TikiGameStatus.completed ||
      TikiGameStatus.lost => false,
    };
  }

  static bool _isOverlayVisible() {
    return TikiTakaPauseSheet.isVisible ||
        TikiTakaFirstWinDialog.isVisible ||
        TikiTakaCompletionDialog.isVisible ||
        TikiTakaLostDialog.isVisible ||
        PlayerSearchDialog.isVisible;
  }

  static void _openPauseSheet(BuildContext context) {
    if (_isOverlayVisible()) {
      return;
    }
    unawaited(TikiTakaPauseSheet.show(context));
  }

  static Future<void> _handleBack(BuildContext context) async {
    if (_isOverlayVisible()) {
      return;
    }

    final cubit = context.read<TikiTakaCubit>();
    final confirmed = await ExitGameDialog.show(
      context,
      lifecycle: ExitGameDialogLifecycle(
        isMatchActive: () => _isActiveMatch(cubit.state.status),
        pauseMatch: cubit.pauseTimer,
        resumeMatch: cubit.resumeTimer,
        isSessionOpen: () => !cubit.isClosed,
      ),
    );
    if (!context.mounted || !confirmed) {
      return;
    }

    cubit.exitMatch();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    }
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
            FocusManager.instance.primaryFocus?.unfocus();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) {
                return;
              }

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
            });
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          unawaited(_handleBack(context));
        },
        child: TikiTakaWarmupLayer(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: _systemUi,
            child: AppScaffold(
            fullWidthHeader: true,
            resizeToAvoidBottomInset: false,
            header: BlocBuilder<TikiTakaCubit, TikiTakaState>(
              buildWhen: (previous, current) =>
                  previous.canClearBoard != current.canClearBoard,
              builder: (context, state) {
                return _TikiTakaHeader(
                  onPause: () => _openPauseSheet(context),
                  onRestart: () {
                    if (_isOverlayVisible()) {
                      return;
                    }
                    unawaited(context.read<TikiTakaCubit>().restart());
                  },
                  onClearBoard: state.canClearBoard
                      ? () => context.read<TikiTakaCubit>().clearBoard()
                      : null,
                );
              },
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AppSpacing.stackMd.h),
                BlocBuilder<TikiTakaCubit, TikiTakaState>(
                  buildWhen: (previous, current) =>
                      previous.hearts != current.hearts ||
                      previous.elapsedMs != current.elapsedMs,
                  builder: (context, state) {
                    return TikiTakaHud(
                      hearts: state.hearts,
                      elapsedMs: state.elapsedMs,
                    );
                  },
                ),
                SizedBox(height: AppSpacing.stackMd.h),
                Expanded(
                  child: BlocBuilder<TikiTakaCubit, TikiTakaState>(
                    buildWhen: (previous, current) =>
                        previous.status != current.status ||
                        previous.rowHeaders != current.rowHeaders ||
                        previous.columnHeaders != current.columnHeaders,
                    builder: (context, state) {
                      if (state.status == TikiGameStatus.loadingBoard) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (state.rowHeaders.length == 3 &&
                          state.columnHeaders.length == 3) {
                        return TikiBoardFrameLoader(
                          rowHeaders: state.rowHeaders,
                          columnHeaders: state.columnHeaders,
                          board: const TikiTakaBoard(),
                        );
                      }

                      return TikiTakaBoardUnavailableView(
                        onRetry: () =>
                            context.read<TikiTakaCubit>().loadBoard(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _TikiTakaHeader extends StatelessWidget {
  const _TikiTakaHeader({
    required this.onPause,
    required this.onRestart,
    this.onClearBoard,
  });

  static const Key clearBoardButtonKey = Key('tiki_clear_board');
  static const Key restartTitleKey = Key('tiki_restart_title');

  final VoidCallback onPause;
  final VoidCallback onRestart;
  final VoidCallback? onClearBoard;

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
            vertical: 8.h,
            horizontal: AppSpacing.containerPadding.w,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppIconButton(
                iconAsset: IconConstant.pause,
                semanticLabel: 'Pause',
                onPressed: onPause,
              ),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Restart match',
                    child: Material(
                      type: MaterialType.transparency,
                      clipBehavior: Clip.none,
                      child: InkWell(
                        key: restartTitleKey,
                        onTap: () {
                          Feedback.forTap(context);
                          onRestart();
                        },
                        borderRadius: AppSpacing.borderRadiusMd,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: Text(
                            'Tiki-Taka',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.titleXs.copyWith(
                              color: AppColors.inkNavy,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AppIconButton(
                key: clearBoardButtonKey,
                iconAsset: IconConstant.restart,
                semanticLabel: 'Clear board',
                onPressed: onClearBoard,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
