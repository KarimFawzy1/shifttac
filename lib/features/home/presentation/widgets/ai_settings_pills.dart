import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../game/domain/models/bot_difficulty.dart';
import '../../../game/domain/models/game_mode.dart';

class AiSettingsPills extends StatefulWidget {
  const AiSettingsPills({
    super.key,
    required this.mode,
    required this.difficulty,
    required this.onModeChanged,
    required this.onDifficultyChanged,
  });

  final GameMode mode;
  final BotDifficulty difficulty;
  final ValueChanged<GameMode> onModeChanged;
  final ValueChanged<BotDifficulty> onDifficultyChanged;

  @override
  State<AiSettingsPills> createState() => _AiSettingsPillsState();
}

class _AiSettingsPillsState extends State<AiSettingsPills> {
  _PillKind? _openPill;

  void _setOpenPill(_PillKind? value) {
    if (!mounted || _openPill == value) {
      return;
    }
    setState(() => _openPill = value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MorphSelectionPill<GameMode>(
          kind: _PillKind.mode,
          isOpen: _openPill == _PillKind.mode,
          label: _modeLabel(widget.mode),
          options: const [GameMode.shift, GameMode.classic],
          selectedValue: widget.mode,
          onOpenChanged: _setOpenPill,
          onChanged: widget.onModeChanged,
          optionLabel: _modeLabel,
          compactWidth: 74,
          expandedWidth: 122,
        ),
        SizedBox(width: 4.w),
        _MorphSelectionPill<BotDifficulty>(
          kind: _PillKind.difficulty,
          isOpen: _openPill == _PillKind.difficulty,
          label: _difficultyLabel(widget.difficulty),
          options: const [
            BotDifficulty.easy,
            BotDifficulty.intermediate,
            BotDifficulty.hard,
          ],
          selectedValue: widget.difficulty,
          onOpenChanged: _setOpenPill,
          onChanged: widget.onDifficultyChanged,
          optionLabel: _difficultyLabel,
          compactWidth: 74,
          expandedWidth: 140,
        ),
      ],
    );
  }

  static String _modeLabel(GameMode mode) {
    return switch (mode) {
      GameMode.shift => 'ShiftTac',
      GameMode.classic => 'Classic',
    };
  }

  static String _difficultyLabel(BotDifficulty difficulty) {
    return switch (difficulty) {
      BotDifficulty.easy => 'Easy',
      BotDifficulty.intermediate => 'Intermediate',
      BotDifficulty.hard => 'Hard',
    };
  }
}

enum _PillKind { mode, difficulty }

const double _sheetOptionRowHeight = 32;
const double _sheetVerticalPadding = 0;

class _MorphSelectionPill<T> extends StatefulWidget {
  const _MorphSelectionPill({
    required this.kind,
    required this.isOpen,
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onOpenChanged,
    required this.onChanged,
    required this.optionLabel,
    required this.compactWidth,
    required this.expandedWidth,
  });

  final _PillKind kind;
  final bool isOpen;
  final String label;
  final List<T> options;
  final T selectedValue;
  final ValueChanged<_PillKind?> onOpenChanged;
  final ValueChanged<T> onChanged;
  final String Function(T value) optionLabel;
  final double compactWidth;
  final double expandedWidth;

  @override
  State<_MorphSelectionPill<T>> createState() => _MorphSelectionPillState<T>();
}

class _MorphSelectionPillState<T> extends State<_MorphSelectionPill<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _entry;

  static const _duration = Duration(milliseconds: 300);
  static const _curve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didUpdateWidget(covariant _MorphSelectionPill<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen == oldWidget.isOpen) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.isOpen) {
        _open();
        return;
      }
      unawaited(_close());
    });
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_entry != null) {
      return;
    }
    unawaited(AppAudioScope.read(context).playSwipe());
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    await _controller.forward(from: 0);
  }

  Future<void> _close() async {
    if (_entry == null) {
      return;
    }
    unawaited(AppAudioScope.read(context).playSwipe());
    await _controller.reverse();
    _entry?.remove();
    _entry = null;
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildOverlay(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = Curves.easeOut.transform(_controller.value);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onOpenChanged(null),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.14 * value),
                ),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset.zero,
              targetAnchor: Alignment.topRight,
              followerAnchor: Alignment.topRight,
              child: _MorphingSheet<T>(
                progress: CurvedAnimation(parent: _controller, curve: _curve),
                compactWidth: widget.compactWidth,
                compactHeight: 28,
                expandedWidth: widget.expandedWidth,
                compactLabel: widget.label,
                selectedValue: widget.selectedValue,
                options: widget.options,
                optionLabel: widget.optionLabel,
                onOptionTap: (value) {
                  widget.onChanged(value);
                  widget.onOpenChanged(null);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IgnorePointer(
        ignoring: widget.isOpen,
        child: Opacity(
          opacity: widget.isOpen ? 0.0 : 1.0,
          child: _CollapsedPill(
            key: Key('ai-pill-${widget.kind.name}'),
            label: widget.label,
            width: widget.compactWidth,
            onTap: () => widget.onOpenChanged(widget.kind),
          ),
        ),
      ),
    );
  }
}

class _CollapsedPill extends StatelessWidget {
  const _CollapsedPill({
    super.key,
    required this.label,
    required this.width,
    required this.onTap,
  });

  final String label;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 28,
      child: Material(
        color: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusFull,
          side: const BorderSide(color: AppColors.outlineVariant),
        ),
        child: InkWell(
          borderRadius: AppSpacing.borderRadiusFull,
          onTap: () {
            Feedback.forTap(context);
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 14.w,
                  color: AppColors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphingSheet<T> extends StatelessWidget {
  const _MorphingSheet({
    required this.progress,
    required this.compactWidth,
    required this.compactHeight,
    required this.expandedWidth,
    required this.compactLabel,
    required this.selectedValue,
    required this.options,
    required this.optionLabel,
    required this.onOptionTap,
  });

  final Animation<double> progress;
  final double compactWidth;
  final double compactHeight;
  final double expandedWidth;
  final String compactLabel;
  final T selectedValue;
  final List<T> options;
  final String Function(T value) optionLabel;
  final ValueChanged<T> onOptionTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final expandedHeight =
            (options.length * _sheetOptionRowHeight + _sheetVerticalPadding * 2)
                .h;
        final t = progress.value;
        final width = lerpDouble(compactWidth, expandedWidth, t)!;
        final height = lerpDouble(compactHeight, expandedHeight, t)!;
        // Morph corners from the true pill radius to sheet corners.
        final startRadius = compactHeight / 2;
        final radius = lerpDouble(startRadius, AppSpacing.radiusLg, t)!;
        final contentOpacity = ((t - 0.9) / 0.1).clamp(0.0, 1.0);
        final pillOpacity = (1 - (t * 1.8)).clamp(0.0, 1.0);
        return Material(
          color: AppColors.surfaceContainerLowest,
          elevation: lerpDouble(0, 6, t)!,
          shadowColor: AppColors.inkNavy.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Opacity(
                  opacity: pillOpacity,
                  child: _CollapsedPill(
                    label: compactLabel,
                    width: compactWidth,
                    onTap: () {},
                  ),
                ),
                if (contentOpacity > 0)
                  Opacity(
                    opacity: contentOpacity,
                    child: ClipRect(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: _sheetVerticalPadding.h,
                          horizontal: 0,
                        ),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < options.length; i++)
                                _SheetOptionRow(
                                  label: optionLabel(options[i]),
                                  rowKey: Key(
                                    'ai-option-${optionLabel(options[i]).toLowerCase()}',
                                  ),
                                  selected: options[i] == selectedValue,
                                  isFirst: i == 0,
                                  isLast: i == options.length - 1,
                                  showDivider: i < options.length - 1,
                                  onTap: () => onOptionTap(options[i]),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetOptionRow extends StatelessWidget {
  const _SheetOptionRow({
    required this.rowKey,
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.showDivider,
    required this.onTap,
  });

  final Key rowKey;
  final String label;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: rowKey,
      height: _sheetOptionRowHeight.h,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppSpacing.borderRadiusDefault,
          onTap: () {
            Feedback.forTap(context);
            onTap();
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.09)
                  : Colors.transparent,
              borderRadius: selected
                  ? BorderRadius.only(
                      topLeft: Radius.circular(
                        isFirst ? AppSpacing.radiusMd : 0,
                      ),
                      topRight: Radius.circular(
                        isFirst ? AppSpacing.radiusMd : 0,
                      ),
                      bottomLeft: Radius.circular(
                        isLast ? AppSpacing.radiusMd : 0,
                      ),
                      bottomRight: Radius.circular(
                        isLast ? AppSpacing.radiusMd : 0,
                      ),
                    )
                  : null,
              border: showDivider
                  ? Border(
                      bottom: BorderSide(
                        color: AppColors.outlineVariant.withValues(alpha: 0.55),
                        width: 0.8,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.labelSm.copyWith(
                        color: selected
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16.w,
                      color: AppColors.primary,
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
