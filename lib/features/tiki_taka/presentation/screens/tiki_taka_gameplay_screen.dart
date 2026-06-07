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
import '../widgets/tiki_board_frame.dart';
import '../widgets/tiki_taka_board.dart';
import '../widgets/tiki_taka_hud.dart';

/// Playable Tiki-Taka 1P board screen (search/dialog polish in Phase T7).
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        context.read<TikiTakaCubit>().exitMatch();
        Navigator.of(context).maybePop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemUi,
        child: AppScaffold(
          fullWidthHeader: true,
          header: _TikiTakaHeader(
            onBack: () {
              context.read<TikiTakaCubit>().exitMatch();
              Navigator.of(context).maybePop();
            },
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
                          BlocBuilder<TikiTakaCubit, TikiTakaState>(
                            buildWhen: (previous, current) =>
                                previous.activeCell != current.activeCell,
                            builder: (context, state) {
                              if (state.activeCell == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: EdgeInsets.only(top: AppSpacing.stackSm.h),
                                child: const _SearchPlaceholderBanner(),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    const Expanded(
                      child: Center(
                        child: Text('Board unavailable'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TikiTakaHeader extends StatelessWidget {
  const _TikiTakaHeader({required this.onBack});

  final VoidCallback onBack;

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
                iconAsset: IconConstant.back,
                semanticLabel: 'Back',
                onPressed: onBack,
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

class _SearchPlaceholderBanner extends StatelessWidget {
  const _SearchPlaceholderBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.25),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Text(
          'Player search opens here (Phase T7)',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
