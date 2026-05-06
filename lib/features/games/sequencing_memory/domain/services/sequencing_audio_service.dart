import 'dart:async';

abstract interface class SequencingAudioPlayback {
  void pause();
  void resume();
  void cancel();
}

abstract interface class SequencingAudioService {
  SequencingAudioPlayback playSequence({
    required List<String> items,
    required void Function(int spokenCount) onProgress,
    required void Function() onComplete,
  });
}

class MockSequencingAudioService implements SequencingAudioService {
  const MockSequencingAudioService({
    this.itemDuration = const Duration(milliseconds: 850),
    this.pauseBetweenItems = const Duration(milliseconds: 240),
  });

  final Duration itemDuration;
  final Duration pauseBetweenItems;

  @override
  SequencingAudioPlayback playSequence({
    required List<String> items,
    required void Function(int spokenCount) onProgress,
    required void Function() onComplete,
  }) {
    return _MockSequencingAudioPlayback(
      items: items,
      itemDelay: itemDuration + pauseBetweenItems,
      onProgress: onProgress,
      onComplete: onComplete,
    )..start();
  }
}

class _MockSequencingAudioPlayback implements SequencingAudioPlayback {
  _MockSequencingAudioPlayback({
    required this.items,
    required this.itemDelay,
    required this.onProgress,
    required this.onComplete,
  });

  final List<String> items;
  final Duration itemDelay;
  final void Function(int spokenCount) onProgress;
  final void Function() onComplete;

  Timer? _timer;
  int _spokenCount = 0;
  bool _paused = false;
  bool _cancelled = false;

  void start() {
    onProgress(0);
    _scheduleNext();
  }

  @override
  void pause() {
    if (_cancelled) {
      return;
    }
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void resume() {
    if (_cancelled || !_paused) {
      return;
    }
    _paused = false;
    _scheduleNext();
  }

  @override
  void cancel() {
    _cancelled = true;
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleNext() {
    if (_cancelled || _paused) {
      return;
    }
    if (_spokenCount >= items.length) {
      scheduleMicrotask(() {
        if (!_cancelled && !_paused) {
          onComplete();
        }
      });
      return;
    }
    _timer = Timer(itemDelay, () {
      if (_cancelled || _paused) {
        return;
      }
      _spokenCount += 1;
      onProgress(_spokenCount);
      _scheduleNext();
    });
  }
}
