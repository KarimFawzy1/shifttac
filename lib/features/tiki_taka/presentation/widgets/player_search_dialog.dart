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

  @visibleForTesting
  static bool get isVisible => _isVisible;

  @visibleForTesting
  static void resetVisibilityForTest() {
    _isVisible = false;
  }

  @visibleForTesting
  static const Key searchFieldKey = _SearchField.fieldKey;

  static Future<void> show(BuildContext context) {
    if (_isVisible) {
      return Future<void>.value();
    }

    final cubit = context.read<TikiTakaCubit>();
    final activeCell = cubit.state.activeCell;
    final board = cubit.state.game.board;
    if (activeCell == null || board == null) {
      return Future<void>.value();
    }

    final rowAttribute = board.rowAttributes[activeCell.row];
    final columnAttribute = board.columnAttributes[activeCell.col];
    final localizations = MaterialLocalizations.of(context);

    _isVisible = true;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: localizations.modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: _animationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return BlocProvider.value(
          value: cubit,
          child: FutureBuilder<TikiAttributeAssetManifest>(
            future: TikiAttributeAssetManifest.load(),
            builder: (context, snapshot) {
              final manifest = snapshot.data;
              if (manifest == null) {
                return const SizedBox.shrink();
              }

              return PlayerSearchDialog._(
                routeAnimation: animation,
                rowAttribute: rowAttribute,
                columnAttribute: columnAttribute,
                manifest: manifest,
              );
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ).whenComplete(() {
      _isVisible = false;
      if (!cubit.isClosed && cubit.state.activeCell != null) {
        cubit.closeSearch();
      }
    });
  }

  @override
  State<PlayerSearchDialog> createState() => _PlayerSearchDialogState();
}

class _PlayerSearchDialogState extends State<PlayerSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

    if (result == TikiSelectPlayerResult.rejectedInvalid) {
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
    required this.rowAttribute,
    required this.columnAttribute,
    required this.manifest,
    required this.onClose,
    required this.onPlayerSelected,
  });

  final TextEditingController queryController;
  final TikiAttribute rowAttribute;
  final TikiAttribute columnAttribute;
  final TikiAttributeAssetManifest manifest;
  final VoidCallback onClose;
  final ValueChanged<TikiPlayerSearchResult> onPlayerSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Player search',
      child: SafeArea(
        top: false,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  _SearchField(controller: queryController),
                  SizedBox(height: AppSpacing.stackSm.h),
                  BlocBuilder<TikiTakaCubit, TikiTakaState>(
                    buildWhen: (previous, current) =>
                        previous.searchQuery != current.searchQuery ||
                        previous.searchResults != current.searchResults ||
                        previous.isSearching != current.isSearching ||
                        previous.inputLocked != current.inputLocked,
                    builder: (context, state) {
                      return _SearchResultsPanel(
                        query: state.searchQuery,
                        results: state.searchResults,
                        isSearching: state.isSearching,
                        selectionLocked: state.inputLocked,
                        onPlayerSelected: onPlayerSelected,
                      );
                    },
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
  const _SearchField({required this.controller});

  static const Key fieldKey = Key('tiki_player_search_field');

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
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
      return _StatusMessage(
        icon: Icons.person_search_outlined,
        message: 'Search for a player who matches both attributes.',
      );
    }

    if (isSearching) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (results.isEmpty) {
      return _StatusMessage(
        icon: Icons.search_off_rounded,
        message: 'No players found for "$trimmedQuery".',
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 280.h),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.borderRadiusMd,
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: ListView.separated(
          shrinkWrap: true,
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
              enabled: !selectionLocked,
              onTap: () => onPlayerSelected(player),
            );
          },
        ),
      ),
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
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Column(
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
