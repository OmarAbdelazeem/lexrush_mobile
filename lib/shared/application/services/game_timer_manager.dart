import 'dart:async';

import 'package:flutter/foundation.dart';

typedef TickCallback = void Function(int secondsLeft);

class GameTimerManager {
  Timer? _timer;
  int _secondsLeft = 0;

  bool get isRunning => _timer?.isActive ?? false;
  int get secondsLeft => _secondsLeft;

  void start({
    required int durationSeconds,
    required TickCallback onTick,
    required VoidCallback onFinished,
  }) {
    cancel();
    _secondsLeft = durationSeconds;
    debugPrint('[GameTimerManager] start duration=$durationSeconds');
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _secondsLeft = (_secondsLeft - 1).clamp(0, durationSeconds);
      debugPrint('[GameTimerManager] tick secondsLeft=$_secondsLeft');
      onTick(_secondsLeft);
      if (_secondsLeft <= 0) {
        debugPrint('[GameTimerManager] finished');
        cancel();
        onFinished();
      }
    });
  }

  void pause() {
    debugPrint('[GameTimerManager] pause');
    _timer?.cancel();
    _timer = null;
  }

  void resume({
    required TickCallback onTick,
    required VoidCallback onFinished,
  }) {
    if (_secondsLeft <= 0 || isRunning) return;
    debugPrint('[GameTimerManager] resume secondsLeft=$_secondsLeft');
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _secondsLeft = (_secondsLeft - 1).clamp(0, _secondsLeft);
      debugPrint('[GameTimerManager] tick secondsLeft=$_secondsLeft');
      onTick(_secondsLeft);
      if (_secondsLeft <= 0) {
        debugPrint('[GameTimerManager] finished');
        cancel();
        onFinished();
      }
    });
  }

  void applyPenaltySeconds(int seconds) {
    _secondsLeft = (_secondsLeft - seconds).clamp(0, _secondsLeft);
    debugPrint('[GameTimerManager] penalty seconds=$seconds -> $_secondsLeft');
  }

  void cancel() {
    if (_timer != null) {
      debugPrint('[GameTimerManager] cancel');
    }
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    debugPrint('[GameTimerManager] dispose');
    cancel();
  }
}
