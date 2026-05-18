/// Bottom navigation tabs inside [MainShellScreen].
enum MainShellTab {
  home,
  rules,
  settings;

  int get tabIndex => switch (this) {
        MainShellTab.home => 0,
        MainShellTab.rules => 1,
        MainShellTab.settings => 2,
      };

  static MainShellTab? fromIndex(int index) {
    for (final tab in MainShellTab.values) {
      if (tab.tabIndex == index) {
        return tab;
      }
    }
    return null;
  }
}
