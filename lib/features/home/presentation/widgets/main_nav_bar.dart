import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Mobile bottom navigation (`css/HomeScreen.css` §Mobile Navigation).
///
/// Spans the full screen width and sits flush on the bottom (including home
/// indicator inset). Sizes scale via [ScreenUtil] from [AppConstants.designSize].
class MainNavBar extends StatefulWidget {
  const MainNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  static const animationDuration = Duration(milliseconds: 280);

  static const _items = [
    MainNavBarItemData(
      iconAsset: IconConstant.home,
      label: 'Home',
      iconWidth: 18,
      iconHeight: 20,
    ),
    MainNavBarItemData(
      iconAsset: IconConstant.rules,
      label: 'Rules',
      iconSize: 22,
    ),
    MainNavBarItemData(
      iconAsset: IconConstant.settings,
      label: 'Settings',
      iconSize: 22,
    ),
  ];

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  final _stackKey = GlobalKey();
  final List<GlobalKey> _itemKeys = List<GlobalKey>.generate(
    MainNavBar._items.length,
    (_) => GlobalKey(),
  );

  double _indicatorLeft = 0;
  double _indicatorWidth = 0;
  var _indicatorReady = false;
  List<double> _itemCenterXs = const [];

  @override
  void initState() {
    super.initState();
    _scheduleIndicatorUpdate();
  }

  @override
  void didUpdateWidget(MainNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scheduleIndicatorUpdate();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleIndicatorUpdate();
  }

  void _scheduleIndicatorUpdate() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _applyIndicatorBounds(),
    );
  }

  void _applyIndicatorBounds() {
    if (!mounted) {
      return;
    }

    final centers = <double>[];
    for (var i = 0; i < MainNavBar._items.length; i++) {
      final itemBounds = _itemBoundsFor(i);
      if (itemBounds == null) {
        return;
      }
      centers.add(itemBounds.left + (itemBounds.width / 2));
    }

    final selectedBounds = _itemBoundsFor(widget.selectedIndex);
    if (selectedBounds == null) {
      return;
    }

    final unchanged =
        _indicatorReady &&
        _itemCenterXs.length == centers.length &&
        (_indicatorLeft - selectedBounds.left).abs() < 0.5 &&
        (_indicatorWidth - selectedBounds.width).abs() < 0.5 &&
        !_centersChanged(centers);

    if (unchanged) {
      return;
    }

    setState(() {
      _itemCenterXs = centers;
      _indicatorLeft = selectedBounds.left;
      _indicatorWidth = selectedBounds.width;
      _indicatorReady = true;
    });
  }

  bool _centersChanged(List<double> next) {
    if (_itemCenterXs.length != next.length) {
      return true;
    }
    for (var i = 0; i < next.length; i++) {
      if ((_itemCenterXs[i] - next[i]).abs() > 0.5) {
        return true;
      }
    }
    return false;
  }

  /// Maps a tap anywhere in the nav strip to the nearest tab by horizontal
  /// midpoints between measured item centers (covers gutters and gaps).
  int _tabIndexForTapX(double xInStack) {
    if (_itemCenterXs.isEmpty) {
      return widget.selectedIndex;
    }
    if (_itemCenterXs.length == 1) {
      return 0;
    }
    for (var i = 0; i < _itemCenterXs.length - 1; i++) {
      final midpoint = (_itemCenterXs[i] + _itemCenterXs[i + 1]) / 2;
      if (xInStack < midpoint) {
        return i;
      }
    }
    return _itemCenterXs.length - 1;
  }

  void _handleBarTap(TapUpDetails details, MainNavMetrics metrics) {
    if (_itemCenterXs.length != MainNavBar._items.length) {
      return;
    }
    final xInStack = details.localPosition.dx - metrics.horizontalPadding;
    final index = _tabIndexForTapX(xInStack);
    if (index != widget.selectedIndex) {
      Feedback.forTap(context);
    }
    widget.onTabSelected(index);
  }

  Rect? _itemBoundsFor(int index) => _indicatorBoundsFor(index);

  Rect? _indicatorBoundsFor(int index) {
    final itemContext = _itemKeys[index].currentContext;
    final stackContext = _stackKey.currentContext;
    if (itemContext == null || stackContext == null) {
      return null;
    }

    final itemBox = itemContext.findRenderObject() as RenderBox?;
    final stackBox = stackContext.findRenderObject() as RenderBox?;
    if (itemBox == null || stackBox == null || !itemBox.hasSize) {
      return null;
    }

    final topLeft = itemBox.localToGlobal(Offset.zero, ancestor: stackBox);
    return topLeft & itemBox.size;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = MainNavMetrics.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Main navigation',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusMd.r),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkNavy.withValues(alpha: 0.05),
              offset: Offset(0, -4.h),
              blurRadius: 12.r,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: metrics.barHeight,
              width: double.infinity,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) => _handleBarTap(details, metrics),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: metrics.horizontalPadding,
                    right: metrics.horizontalPadding,
                    top: metrics.barEdgePadding,
                    bottom: metrics.barEdgePadding,
                  ),
                  child: SizedBox(
                    height: metrics.itemSlotHeight,
                    child: Stack(
                      key: _stackKey,
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        if (_indicatorReady)
                          AnimatedPositioned(
                            duration: MainNavBar.animationDuration,
                            curve: Curves.easeOutCubic,
                            left: _indicatorLeft,
                            width: _indicatorWidth,
                            top: 0,
                            height: metrics.itemSlotHeight,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: AppSpacing.borderRadiusMd,
                                ),
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (var i = 0; i < MainNavBar._items.length; i++)
                              MainNavBarItem(
                                key: _itemKeys[i],
                                data: MainNavBar._items[i],
                                metrics: metrics,
                                selected: widget.selectedIndex == i,
                                onTap: () => widget.onTabSelected(i),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (bottomInset > 0)
            ColoredBox(
              color: AppColors.surfaceContainerLowest,
              child: SizedBox(width: double.infinity, height: bottomInset),
            ),
          ],
        ),
      ),
    );
  }
}

/// Design tokens for the bottom nav at [AppConstants.designSize] (390×844).
class MainNavMetrics {
  const MainNavMetrics({
    required this.horizontalPadding,
    required this.barEdgePadding,
    required this.barHeight,
    required this.itemSlotHeight,
    required this.iconLabelGap,
    required this.itemHorizontalPadding,
    required this.itemVerticalPadding,
    required this.labelStyle,
    required this.inactiveLabelStyle,
  });

  /// Largest icon height used in nav items (design dp).
  static const double _tallestIconDp = 22;

  factory MainNavMetrics.of(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final designHorizontalPadding = 54.w;
    final horizontalPadding = designHorizontalPadding.clamp(
      AppSpacing.stackMd.w,
      screenWidth * 0.16,
    );

    final iconLabelGap = 6.h;
    final itemVerticalPadding = 4.h;
    final itemHorizontalPadding = 16.w;
    final tallestIcon = _tallestIconDp.h;
    final labelHeight = 14.h;
    final itemSlotHeight =
        tallestIcon + iconLabelGap + labelHeight + (itemVerticalPadding * 2);

    // Total outer inset (top + bottom). `barHeight` uses 1.5× the 12dp side token.
    final barOuterVerticalInset = 12.h;
    final barEdgePadding = barOuterVerticalInset / 2;
    final barHeight = itemSlotHeight + barOuterVerticalInset;

    final labelStyle = AppTextStyles.labelSm.copyWith(
      fontSize: 12.sp,
      height: 14 / 12,
      color: AppColors.primary,
    );

    return MainNavMetrics(
      horizontalPadding: horizontalPadding,
      barEdgePadding: barEdgePadding,
      barHeight: barHeight,
      itemSlotHeight: itemSlotHeight,
      iconLabelGap: iconLabelGap,
      itemHorizontalPadding: itemHorizontalPadding,
      itemVerticalPadding: itemVerticalPadding,
      labelStyle: labelStyle,
      inactiveLabelStyle: labelStyle.copyWith(color: AppColors.outline),
    );
  }

  final double horizontalPadding;

  /// Top/bottom inset around the tab row (`12.h * 1.5 / 2` per edge).
  final double barEdgePadding;
  final double barHeight;
  final double itemSlotHeight;
  final double iconLabelGap;
  final double itemHorizontalPadding;
  final double itemVerticalPadding;
  final TextStyle labelStyle;
  final TextStyle inactiveLabelStyle;
}

class MainNavBarItemData {
  const MainNavBarItemData({
    required this.iconAsset,
    required this.label,
    this.iconSize,
    this.iconWidth,
    this.iconHeight,
  }) : assert(
         (iconSize != null) ^ (iconWidth != null && iconHeight != null),
         'Provide iconSize or both iconWidth and iconHeight',
       );

  final String iconAsset;
  final String label;
  final double? iconSize;
  final double? iconWidth;
  final double? iconHeight;

  double get resolvedIconWidth => iconWidth ?? iconSize!;
  double get resolvedIconHeight => iconHeight ?? iconSize!;
}

class MainNavBarItem extends StatelessWidget {
  const MainNavBarItem({
    super.key,
    required this.data,
    required this.metrics,
    required this.selected,
    required this.onTap,
  });

  final MainNavBarItemData data;
  final MainNavMetrics metrics;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = AppColors.outline;
    final activeColor = AppColors.primary;
    final textStyle = selected
        ? metrics.labelStyle
        : metrics.inactiveLabelStyle;

    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Feedback.forTap(context);
            onTap();
          },
          borderRadius: AppSpacing.borderRadiusMd,
          child: SizedBox(
            height: metrics.itemSlotHeight,
            child: Center(
              child: AnimatedOpacity(
                duration: MainNavBar.animationDuration,
                curve: Curves.easeOutCubic,
                opacity: selected ? 1 : 0.7,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.itemHorizontalPadding,
                    vertical: metrics.itemVerticalPadding,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<Color?>(
                        duration: MainNavBar.animationDuration,
                        curve: Curves.easeOutCubic,
                        tween: ColorTween(
                          begin: inactiveColor,
                          end: selected ? activeColor : inactiveColor,
                        ),
                        builder: (context, color, _) {
                          return SvgPicture.asset(
                            data.iconAsset,
                            width: data.resolvedIconWidth.w,
                            height: data.resolvedIconHeight.h,
                            colorFilter: ColorFilter.mode(
                              color ?? inactiveColor,
                              BlendMode.srcIn,
                            ),
                          );
                        },
                      ),
                      SizedBox(height: metrics.iconLabelGap),
                      AnimatedDefaultTextStyle(
                        duration: MainNavBar.animationDuration,
                        curve: Curves.easeOutCubic,
                        style: textStyle,
                        maxLines: 1,
                        child: Text(data.label, textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

