import 'package:flutter/foundation.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';
import 'package:lexrush/shared/domain/contracts/audio_feedback_port.dart';
import 'package:lexrush/shared/domain/contracts/haptics_port.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';

class NoopAnalyticsPort implements AnalyticsPort {
  @override
  Future<void> trackGameFinished(
    GameMode mode, {
    required int score,
    required int accuracy,
  }) async {
    debugPrint('[NoopAnalytics] game_finished mode=$mode score=$score accuracy=$accuracy');
  }

  @override
  Future<void> trackGameStarted(GameMode mode) async {
    debugPrint('[NoopAnalytics] game_started mode=$mode');
  }

  @override
  Future<void> trackRoundOutcome(GameMode mode, String outcome) async {
    debugPrint('[NoopAnalytics] round_outcome mode=$mode outcome=$outcome');
  }
}

class NoopAudioFeedbackPort implements AudioFeedbackPort {
  @override
  Future<void> playError() async => debugPrint('[NoopAudio] error');

  @override
  Future<void> playMissed() async => debugPrint('[NoopAudio] missed');

  @override
  Future<void> playSuccess() async => debugPrint('[NoopAudio] success');
}

class NoopHapticsPort implements HapticsPort {
  @override
  Future<void> heavyImpact() async => debugPrint('[NoopHaptics] heavy');

  @override
  Future<void> lightImpact() async => debugPrint('[NoopHaptics] light');
}
