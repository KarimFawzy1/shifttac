import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/audio/app_audio.dart';
import 'state/game_cubit.dart';

/// Gameplay SFX entry points (board taps, restart).
abstract final class GameplayAudio {
  GameplayAudio._();

  static void onCellTapResult(BuildContext context, CellTapResult result) {
    final audio = AppAudioScope.read(context);
    switch (result) {
      case CellTapResult.accepted:
        unawaited(audio.playTap());
      case CellTapResult.rejectedInvalid:
      case CellTapResult.rejectedLocked:
      case CellTapResult.rejectedNotPlaying:
        unawaited(audio.playWrongTap());
    }
  }

  static void onRestart(BuildContext context) {
    unawaited(AppAudioScope.read(context).playRestart());
  }
}
