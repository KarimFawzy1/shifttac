import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/audio/app_audio.dart';
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

  late final PageController _pageController;
  late int _selectedIndex;

  /// While true, [PageView.onPageChanged] is ignored so intermediate pages
  /// (e.g. Rules when jumping Home → Settings) do not flash in the nav bar.
  var _syncingPageFromNavTap = false;

  late final List<Widget> _pages = [
    _shellTab(const HomeScreen()),
    _shellTab(
      HowToPlayScreen(
        onGoHome: () => _onTabSelected(MainShellTab.home.tabIndex),
      ),
    ),
    _shellTab(const SettingsScreen()),
  ];

  /// Horizontal inset for tab bodies. Applied per page (not on [PageView]) so
  /// swipes are full-bleed and padding travels with each screen.
  static Widget _shellTab(Widget child) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.containerPadding.w),
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab.tabIndex;
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _playTabSwipeSfx() {
    unawaited(AppAudioScope.read(context).playSwipe());
  }

  void _onPageChanged(int index) {
    if (_syncingPageFromNavTap || index == _selectedIndex) {
      return;
    }
    _playTabSwipeSfx();
    setState(() => _selectedIndex = index);
  }

  Future<void> _onTabSelected(int index) async {
    if (index == _selectedIndex) {
      return;
    }
    _playTabSwipeSfx();
    setState(() {
      _selectedIndex = index;
      _syncingPageFromNavTap = true;
    });
    await _pageController.animateToPage(
      index,
      duration: _transitionDuration,
      curve: Curves.easeOutCubic,
    );
    if (!mounted) {
      return;
    }
    setState(() => _syncingPageFromNavTap = false);
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
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
              children: _pages,
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
