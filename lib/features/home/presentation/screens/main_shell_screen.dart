import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/routing/main_shell_tab.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../how_to_play/presentation/screens/how_to_play_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../widgets/main_nav_bar.dart';
import 'home_screen.dart';

/// Shell hosting Home, Rules, and Settings with shared bottom navigation.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key, this.initialTab = MainShellTab.home});

  final MainShellTab initialTab;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  static const _transitionDuration = Duration(milliseconds: 280);

  late int _selectedIndex;
  int _slideDirection = 1;

  static const _pages = <Widget>[
    HomeScreen(),
    HowToPlayScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab.tabIndex;
  }

  void _onTabSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _slideDirection = index > _selectedIndex ? 1 : -1;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      safeAreaBottom: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.containerPadding.w,
              ),
              child: AnimatedSwitcher(
                duration: _transitionDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) =>
                    currentChild ?? const SizedBox.shrink(),
                transitionBuilder: (child, animation) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  final slide = Tween<Offset>(
                    begin: Offset(_slideDirection * 0.06, 0),
                    end: Offset.zero,
                  ).animate(curved);
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedIndex),
                  child: _pages[_selectedIndex],
                ),
              ),
            ),
          ),
          MainNavBar(
            selectedIndex: _selectedIndex,
            onTabSelected: _onTabSelected,
          ),
        ],
      ),
    );
  }
}
