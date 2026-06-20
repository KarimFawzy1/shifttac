import 'package:flutter/foundation.dart';

/// Debug-only runtime toggles for Tiki-Taka presentation.
class TikiTakaDebugSettings extends ChangeNotifier {
  TikiTakaDebugSettings._();

  static final TikiTakaDebugSettings instance = TikiTakaDebugSettings._();

  bool _forceBoardAvatarLoading = false;

  /// When true (debug builds only), board cells keep the animated loading
  /// placeholder and never show player images.
  bool get forceBoardAvatarLoading => kDebugMode && _forceBoardAvatarLoading;

  set forceBoardAvatarLoading(bool value) {
    if (!kDebugMode) {
      return;
    }
    if (_forceBoardAvatarLoading == value) {
      return;
    }
    _forceBoardAvatarLoading = value;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _forceBoardAvatarLoading = false;
    notifyListeners();
  }
}
