import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

class SequencingAudioProgress {
  const SequencingAudioProgress({
    required this.playbackId,
    required this.spokenCount,
    required this.currentItemIndex,
    this.currentItem,
    this.isComplete = false,
    this.isCancelled = false,
    this.errorMessage,
  });

  final int playbackId;
  final int spokenCount;
  final int currentItemIndex;
  final String? currentItem;
  final bool isComplete;
  final bool isCancelled;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
}

abstract interface class SequencingAudioService {
  int speakSequence(List<String> items);
  int speakItem(String item);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  bool get isSpeaking;
  Stream<SequencingAudioProgress> get progress;
  Future<void> dispose();
}

class MockSequencingAudioService implements SequencingAudioService {
  MockSequencingAudioService({
    this.itemDuration = const Duration(milliseconds: 850),
    this.pauseBetweenItems = const Duration(milliseconds: 240),
  });

  final Duration itemDuration;
  final Duration pauseBetweenItems;

  final StreamController<SequencingAudioProgress> _progress =
      StreamController<SequencingAudioProgress>.broadcast();

  Timer? _timer;
  List<String> _items = const <String>[];
  int _playbackId = 0;
  int _currentIndex = 0;
  int _spokenCount = 0;
  bool _isSpeaking = false;
  bool _paused = false;
  bool _disposed = false;

  @override
  Stream<SequencingAudioProgress> get progress => _progress.stream;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  int speakItem(String item) {
    return speakSequence(<String>[item]);
  }

  @override
  int speakSequence(List<String> items) {
    _cancelTimer();
    _playbackId += 1;
    _items = items.toList(growable: false);
    _currentIndex = 0;
    _spokenCount = 0;
    _isSpeaking = true;
    _paused = false;
    scheduleMicrotask(() {
      if (_isSpeaking && !_paused && !_disposed) {
        _emitCurrent();
        _scheduleNext();
      }
    });
    return _playbackId;
  }

  @override
  Future<void> pause() async {
    if (!_isSpeaking || _disposed) {
      return;
    }
    _paused = true;
    _cancelTimer();
  }

  @override
  Future<void> resume() async {
    if (!_isSpeaking || !_paused || _disposed) {
      return;
    }
    _paused = false;
    _scheduleNext();
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    _cancelTimer();
    if (_isSpeaking) {
      _isSpeaking = false;
      _progress.add(
        SequencingAudioProgress(
          playbackId: _playbackId,
          spokenCount: _spokenCount,
          currentItemIndex: _currentIndex,
          isCancelled: true,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _cancelTimer();
    await _progress.close();
  }

  void _scheduleNext() {
    if (!_isSpeaking || _paused || _disposed) {
      return;
    }
    if (_currentIndex >= _items.length) {
      scheduleMicrotask(_complete);
      return;
    }
    _timer = Timer(itemDuration + pauseBetweenItems, () {
      if (!_isSpeaking || _paused || _disposed) {
        return;
      }
      _spokenCount += 1;
      _currentIndex += 1;
      if (_currentIndex < _items.length) {
        _emitCurrent();
        _scheduleNext();
      } else {
        _complete();
      }
    });
  }

  void _emitCurrent() {
    if (_disposed) {
      return;
    }
    _progress.add(
      SequencingAudioProgress(
        playbackId: _playbackId,
        spokenCount: _spokenCount,
        currentItemIndex: _currentIndex,
        currentItem: _currentIndex < _items.length
            ? _items[_currentIndex]
            : null,
      ),
    );
  }

  void _complete() {
    if (!_isSpeaking || _disposed) {
      return;
    }
    _isSpeaking = false;
    _progress.add(
      SequencingAudioProgress(
        playbackId: _playbackId,
        spokenCount: _items.length,
        currentItemIndex: _items.length,
        isComplete: true,
      ),
    );
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

class DeviceTtsSequencingAudioService implements SequencingAudioService {
  DeviceTtsSequencingAudioService({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts() {
    _ready = _configureTts();
  }

  final FlutterTts _flutterTts;
  late final Future<void> _ready;
  final StreamController<SequencingAudioProgress> _progress =
      StreamController<SequencingAudioProgress>.broadcast();

  List<String> _items = const <String>[];
  int _playbackId = 0;
  int _spokenCount = 0;
  int _currentIndex = 0;
  bool _isSpeaking = false;
  bool _disposed = false;
  bool _stopRequested = false;

  @override
  Stream<SequencingAudioProgress> get progress => _progress.stream;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  int speakItem(String item) {
    return speakSequence(<String>[item]);
  }

  @override
  int speakSequence(List<String> items) {
    _playbackId += 1;
    final int playbackId = _playbackId;
    _items = items.toList(growable: false);
    _spokenCount = 0;
    _currentIndex = 0;
    _isSpeaking = true;
    _stopRequested = false;
    unawaited(_flutterTts.stop());
    scheduleMicrotask(() {
      unawaited(_speakItems(playbackId));
    });
    return playbackId;
  }

  @override
  Future<void> pause() async {
    if (!_isSpeaking || _disposed) {
      return;
    }
    await stop();
  }

  @override
  Future<void> resume() async {
    if (_disposed || _items.isEmpty) {
      return;
    }
    speakSequence(_items);
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    _stopRequested = true;
    if (_isSpeaking) {
      _isSpeaking = false;
      _emit(
        SequencingAudioProgress(
          playbackId: _playbackId,
          spokenCount: _spokenCount,
          currentItemIndex: _currentIndex,
          isCancelled: true,
        ),
      );
    }
    await _flutterTts.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    await stop();
    _disposed = true;
    await _progress.close();
  }

  Future<void> _configureTts() async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    _flutterTts.setCancelHandler(() {
      _handleTerminalEvent(cancelled: true);
    });
    _flutterTts.setErrorHandler((dynamic message) {
      _handleTerminalEvent(errorMessage: '$message');
    });
  }

  Future<void> _speakItems(int playbackId) async {
    await _ready;
    for (int index = 0; index < _items.length; index += 1) {
      if (_disposed || _stopRequested || playbackId != _playbackId) {
        return;
      }
      _currentIndex = index;
      _emit(
        SequencingAudioProgress(
          playbackId: playbackId,
          spokenCount: _spokenCount,
          currentItemIndex: index,
          currentItem: _items[index],
        ),
      );
      final dynamic result = await _flutterTts.speak(_items[index]);
      if (_disposed || _stopRequested || playbackId != _playbackId) {
        return;
      }
      if (result == 0) {
        _handleTerminalEvent(errorMessage: 'Text-to-speech failed to start.');
        return;
      }
      _spokenCount = index + 1;
      _emit(
        SequencingAudioProgress(
          playbackId: playbackId,
          spokenCount: _spokenCount,
          currentItemIndex: index,
          currentItem: _items[index],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    if (_disposed || _stopRequested || playbackId != _playbackId) {
      return;
    }
    _isSpeaking = false;
    _emit(
      SequencingAudioProgress(
        playbackId: playbackId,
        spokenCount: _items.length,
        currentItemIndex: _items.length,
        isComplete: true,
      ),
    );
  }

  void _handleTerminalEvent({bool cancelled = false, String? errorMessage}) {
    if (!_isSpeaking || _disposed) {
      return;
    }
    _isSpeaking = false;
    _emit(
      SequencingAudioProgress(
        playbackId: _playbackId,
        spokenCount: _spokenCount,
        currentItemIndex: _currentIndex,
        isCancelled: cancelled,
        errorMessage: errorMessage,
      ),
    );
  }

  void _emit(SequencingAudioProgress progress) {
    if (!_disposed && !_progress.isClosed) {
      _progress.add(progress);
    }
  }
}
