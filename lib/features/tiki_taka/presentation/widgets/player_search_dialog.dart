import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/modal_backdrop.dart';
import '../../data/models/tiki_attribute.dart';
import '../../data/models/tiki_player_search_result.dart';
import '../../domain/services/tiki_attribute_asset_manifest.dart';
import '../state/tiki_taka_cubit.dart';
import '../state/tiki_taka_state.dart';
import 'player_search_result_tile.dart';
import 'tiki_attribute_header.dart';

/// Search-and-select sheet for filling a Tiki-Taka board cell.
class PlayerSearchDialog extends StatefulWidget {
  const PlayerSearchDialog._({
    required this.routeAnimation,
    required this.rowAttribute,
    required this.columnAttribute,
    required this.manifest,
  });

  @visibleForTesting
  const PlayerSearchDialog.forTest({
    super.key,
    required this.routeAnimation,
    required this.rowAttribute,
    required this.columnAttribute,
    required this.manifest,
  });

  final Animation<double> routeAnimation;
  final TikiAttribute rowAttribute;
  final TikiAttribute columnAttribute;
  final TikiAttributeAssetManifest manifest;

  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const Duration _searchDebounce = Duration(milliseconds: 300);

  static bool _isVisible = false;

  static bool get isVisible => _isVisible;

  @visibleForTesting
  static void resetVisibilityForTest() {
    _isVisible = false;
  }

  @visibleForTesting
  static const Key searchFieldKey = _SearchField.fieldKey;

  static Future<void> show(BuildContext context) async {
    if (_isVisible) {
      return;
    }

    final cubit = context.read<TikiTakaCubit>();
    final activeCell = cubit.state.activeCell;
    final board = cubit.state.game.board;
    if (activeCell == null || board == null) {
      return;
    }

    final rowAttribute = board.rowAttributes[activeCell.row];
    final columnAttribute = board.columnAttributes[activeCell.col];

    TikiAttributeAssetManifest manifest;
    try {
      manifest =
          TikiAttributeAssetManifest.loaded ??
          await TikiAttributeAssetManifest.load();
    } catch (_) {
      manifest = TikiAttributeAssetManifest.empty();
    }

    if (!context.mounted || _isVisible || cubit.state.activeCell == null) {
      return;
    }

    final localizations = MaterialLocalizations.of(context);

    _isVisible = true;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: localizations.modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: _animationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return BlocProvider.value(
          value: cubit,
          child: PlayerSearchDialog._(
            routeAnimation: animation,
            rowAttribute: rowAttribute,
            columnAttribute: columnAttribute,
            manifest: manifest,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
    _isVisible = false;
    if (!cubit.isClosed && cubit.state.activeCell != null) {
      cubit.closeSearch();
    }
  }

  @override
  State<PlayerSearchDialog> createState() => _PlayerSearchDialogState();
}

class _PlayerSearchDialogState extends State<PlayerSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    final existingQuery = context.read<TikiTakaCubit>().state.searchQuery;
    if (existingQuery.isNotEmpty) {
      _queryController.text = existingQuery;
    }
    _queryController.addListener(_onQueryChanged);
    widget.routeAnimation.addStatusListener(_focusSearchWhenReady);
    if (_isOpenAnimationSettled(widget.routeAnimation)) {
      _scheduleSearchFocus();
    }
  }

  bool _isOpenAnimationSettled(Animation<double> animation) {
    return animation.isCompleted || animation.value >= 1.0;
  }

  void _focusSearchWhenReady(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    _scheduleSearchFocus();
  }

  void _scheduleSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    widget.routeAnimation.removeStatusListener(_focusSearchWhenReady);
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    _queryController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(PlayerSearchDialog._searchDebounce, () {
      if (!mounted) {
        return;
      }
      context.read<TikiTakaCubit>().searchPlayers(_queryController.text);
    });
  }

  void _close() {
    if (!mounted || _isClosing) {
      return;
    }

    _isClosing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    context.read<TikiTakaCubit>().closeSearch();
    Navigator.of(context).pop();
  }

  Future<void> _onPlayerSelected(TikiPlayerSearchResult player) async {
    final cubit = context.read<TikiTakaCubit>();
    if (cubit.state.inputLocked) {
      return;
    }

    final result = await cubit.selectPlayer(player);
    if (!mounted) {
      return;
    }

    if (result == TikiSelectPlayerResult.rejectedDuplicatePlayer) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Correct player, but already selected.'),
            duration: Duration(seconds: 2),
          ),
        );
    } else if (result == TikiSelectPlayerResult.rejectedInvalid) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Wrong player — you lost a heart.'),
            duration: Duration(seconds: 2),
          ),
        );
    }

    _close();
  }

  @override
  Widget build(BuildContext context) {
    final backdropCurve = CurvedAnimation(
      parent: widget.routeAnimation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    final sheetCurve = CurvedAnimation(
      parent: widget.routeAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(sheetCurve);

    return AnimatedBuilder(
      animation: backdropCurve,
      builder: (context, child) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ModalBackdrop(
                  progress: backdropCurve.value,
                  enableBlur: backdropCurve.isCompleted,
                  onTap: _close,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(position: sheetSlide, child: child),
              ),
            ],
          ),
        );
      },
      child: _PlayerSearchSheet(
        queryController: _queryController,
        searchFocusNode: _searchFocusNode,
        rowAttribute: widget.rowAttribute,
        columnAttribute: widget.columnAttribute,
        manifest: widget.manifest,
        onClose: _close,
        onPlayerSelected: _onPlayerSelected,
      ),
    );
  }
}

class _PlayerSearchSheet extends StatelessWidget {
  const _PlayerSearchSheet({
    required this.queryController,
    required this.searchFocusNode,
    required this.rowAttribute,
    required this.columnAttribute,
    required this.manifest,
    required this.onClose,
    required this.onPlayerSelected,
  });

  final TextEditingController queryController;
  final FocusNode searchFocusNode;
  final TikiAttribute rowAttribute;
  final TikiAttribute columnAttribute;
  final TikiAttributeAssetManifest manifest;
  final VoidCallback onClose;
  final ValueChanged<TikiPlayerSearchResult> onPlayerSelected;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final innerVerticalPadding = AppSpacing.stackMd.h * 2;
    // Height is independent of the keyboard so the sheet opens directly at its
    // final size and never grows/shrinks while the keyboard animates in.
    final maxSheetHeight =
        mediaQuery.size.height -
        mediaQuery.padding.top -
        innerVerticalPadding -
        24.h;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Player search',
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.stackMd.w),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
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
                AppSpacing.stackMd.h,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: ListenableBuilder(
                  listenable: queryController,
                  builder: (context, _) {
                    return BlocBuilder<TikiTakaCubit, TikiTakaState>(
                      buildWhen: (previous, current) =>
                          previous.searchQuery != current.searchQuery ||
                          previous.searchResults != current.searchResults ||
                          previous.isSearching != current.isSearching ||
                          previous.inputLocked != current.inputLocked,
                      builder: (context, state) {
                        final panelQuery = queryController.text.isNotEmpty
                            ? queryController.text
                            : state.searchQuery;
                        final resultsPanel = _SearchResultsPanel(
                          query: panelQuery,
                          results: state.searchResults,
                          isSearching: state.isSearching,
                          selectionLocked: state.inputLocked,
                          onPlayerSelected: onPlayerSelected,
                        );

                        return Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SheetHandle(onClose: onClose),
                            SizedBox(height: AppSpacing.stackSm.h),
                            Text(
                              'Find a player',
                              style: AppTextStyles.titleXs.copyWith(
                                color: AppColors.inkNavy,
                              ),
                            ),
                            SizedBox(height: AppSpacing.stackSm.h),
                            _CellContextRow(
                              rowAttribute: rowAttribute,
                              columnAttribute: columnAttribute,
                              manifest: manifest,
                            ),
                            SizedBox(height: AppSpacing.stackMd.h),
                            _SearchField(
                              controller: queryController,
                              focusNode: searchFocusNode,
                            ),
                            SizedBox(height: AppSpacing.stackSm.h),
                            // Only the results area accounts for the keyboard,
                            // keeping the sheet frame and search field fixed.
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: keyboardInset),
                                child: resultsPanel,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: SizedBox(width: 40.w, height: 4.h),
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Close',
          icon: Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CellContextRow extends StatelessWidget {
  const _CellContextRow({
    required this.rowAttribute,
    required this.columnAttribute,
    required this.manifest,
  });

  final TikiAttribute rowAttribute;
  final TikiAttribute columnAttribute;
  final TikiAttributeAssetManifest manifest;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Match row ${rowAttribute.displayName} and column ${columnAttribute.displayName}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            child: Row(
              children: [
                Expanded(
                  child: TikiAttributeHeader(
                    attribute: rowAttribute,
                    manifest: manifest,
                    axis: TikiHeaderAxis.row,
                    iconSize: 24.w,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Text(
                    '×',
                    style: AppTextStyles.titleXs.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: TikiAttributeHeader(
                    attribute: columnAttribute,
                    manifest: manifest,
                    axis: TikiHeaderAxis.column,
                    iconSize: 24.w,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode});

  static const Key fieldKey = Key('tiki_player_search_field');

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'Type a player name',
        hintStyle: AppTextStyles.bodyMd.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.onSurfaceVariant,
          size: 22.sp,
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onSubmitted: (_) {},
    );
  }
}

class _SearchResultsPanel extends StatelessWidget {
  const _SearchResultsPanel({
    required this.query,
    required this.results,
    required this.isSearching,
    required this.selectionLocked,
    required this.onPlayerSelected,
  });

  final String query;
  final List<TikiPlayerSearchResult> results;
  final bool isSearching;
  final bool selectionLocked;
  final ValueChanged<TikiPlayerSearchResult> onPlayerSelected;

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return Center(
        child: _StatusMessage(
          icon: Icons.person_search_outlined,
          message: 'Search for a player who matches both attributes.',
        ),
      );
    }

    if (isSearching && results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty) {
      return Center(
        child: _StatusMessage(
          icon: Icons.search_off_rounded,
          message: 'No players found for "$trimmedQuery".',
        ),
      );
    }

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            itemCount: results.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AppColors.outlineVariant.withValues(alpha: 0.35),
            ),
            itemBuilder: (context, index) {
              final player = results[index];
              return PlayerSearchResultTile(
                player: player,
                enabled: !selectionLocked && !isSearching,
                onTap: () => onPlayerSelected(player),
              );
            },
          ),
        ),
        if (isSearching)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2.h,
              backgroundColor: Colors.transparent,
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 28.sp),
          SizedBox(height: AppSpacing.stackSm.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
