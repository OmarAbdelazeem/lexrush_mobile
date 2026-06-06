import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/sequencing_memory/application/cubit/sequencing_memory_cubit.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_stage.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/services/sequencing_audio_service.dart';

void main() {
  group('SequencingMemoryCubit', () {
    test('start initializes challenge 1 and enters listening', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      await _settle();

      expect(cubit.state.currentChallengeIndex, 1);
      expect(cubit.state.totalChallenges, 3);
      expect(cubit.state.stage, SequencingStage.listenPartOne);
      expect(cubit.state.currentRound?.roundId, 1);
      expect(cubit.state.currentCards, isEmpty);
      expect(audio.plays, 1);

      await cubit.close();
    });

    test(
      'audio completion advances to arrange without exposing cards early',
      () async {
        final _ControlledAudioService audio = _ControlledAudioService();
        final SequencingMemoryCubit cubit = SequencingMemoryCubit(
          audioService: audio,
        );

        cubit.start();
        await _settle();
        expect(cubit.state.currentCards, isEmpty);

        audio.complete();
        await _settle();

        expect(cubit.state.stage, SequencingStage.arrangePartOne);
        expect(cubit.state.currentCards, hasLength(3));
        expect(cubit.state.spokenProgress, 3);
        expect(cubit.state.currentSpokenItem, isNull);

        await cubit.close();
      },
    );

    test(
      'spoken item progress updates caption state only while listening',
      () async {
        final _ControlledAudioService audio = _ControlledAudioService();
        final SequencingMemoryCubit cubit = SequencingMemoryCubit(
          audioService: audio,
        );

        cubit.start();
        await _settle();
        audio.emitCurrentItem('Right on Abbeyhill');
        await _settle();

        expect(cubit.state.stage, SequencingStage.listenPartOne);
        expect(cubit.state.currentSpokenItem, 'Right on Abbeyhill');
        expect(cubit.state.currentCards, isEmpty);

        audio.complete();
        await _settle();
        expect(cubit.state.currentSpokenItem, isNull);

        await cubit.close();
      },
    );

    test('reorder plus perfect submit scores a part correctly', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      await _settle();
      audio.complete();
      await _settle();
      _reorderTo(cubit, cubit.state.currentItems);
      cubit.submitCurrentOrder();

      expect(cubit.state.stage, SequencingStage.feedbackPartOne);
      expect(cubit.state.score, 100);
      expect(cubit.state.perfectStages, 1);
      expect(cubit.state.review.single.perfect, isTrue);
      expect(cubit.state.longestSequenceRemembered, 3);

      await cubit.close();
    });

    test('partial submit awards 20 points per correct position', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      await _settle();
      audio.complete();
      await _settle();
      final List<String> target = cubit.state.currentItems;
      _reorderTo(cubit, <String>[target[0], target[2], target[1]]);
      cubit.submitCurrentOrder();

      expect(cubit.state.score, 20);
      expect(cubit.state.lastResult?.correctPositions, 1);
      expect(cubit.state.lastResult?.pointsEarned, 20);
      expect(cubit.state.perfectStages, 0);

      await cubit.close();
    });

    test('replay increments once per part and replays the same part', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      await _settle();
      audio.complete();
      await _settle();
      final List<String> partOne = cubit.state.currentItems;

      cubit.replayCurrentPart();
      await _settle();

      expect(cubit.state.stage, SequencingStage.listenPartOne);
      expect(cubit.state.currentItems, partOne);
      expect(cubit.state.replayCount, 1);
      expect(cubit.state.stageReplayCount, 1);
      expect(audio.plays, 2);

      audio.complete();
      await _settle();
      expect(cubit.state.stage, SequencingStage.arrangePartOne);
      expect(cubit.state.canReplay, isFalse);

      cubit.replayCurrentPart();
      expect(cubit.state.replayCount, 1);
      expect(cubit.state.stage, SequencingStage.arrangePartOne);

      await cubit.close();
    });

    test('part one, part two, and combined stage progression works', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      await _settle();
      audio.complete();
      await _settle();
      _submitPerfect(cubit);
      cubit.continueAfterFeedback();
      await _settle();

      expect(cubit.state.stage, SequencingStage.listenPartTwo);
      audio.complete();
      await _settle();
      _submitPerfect(cubit);
      cubit.continueAfterFeedback();

      expect(cubit.state.stage, SequencingStage.arrangeCombined);
      expect(cubit.state.currentItems, hasLength(6));
      _submitPerfect(cubit);

      expect(cubit.state.stage, SequencingStage.feedbackCombined);
      expect(cubit.state.score, 400);

      await cubit.close();
    });

    test('duplicate audio completion does not advance twice', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      await _settle();
      final int playbackId = audio.activePlaybackId;
      audio.complete(playbackId: playbackId);
      audio.complete(playbackId: playbackId);
      await _settle();

      expect(cubit.state.stage, SequencingStage.arrangePartOne);
      expect(cubit.state.currentRound?.roundId, 1);
      expect(cubit.state.currentCards, hasLength(3));

      await cubit.close();
    });

    test('final result computes honest sequencing metrics', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      await _settle();
      for (int challenge = 0; challenge < 3; challenge += 1) {
        audio.complete();
        await _settle();
        _submitPerfect(cubit);
        cubit.continueAfterFeedback();
        await _settle();
        audio.complete();
        await _settle();
        _submitPerfect(cubit);
        cubit.continueAfterFeedback();
        _submitPerfect(cubit);
        cubit.continueAfterFeedback();
        await _settle();
      }

      expect(cubit.state.stage, SequencingStage.finished);
      expect(cubit.state.result, isNotNull);
      expect(cubit.state.result?.summary.stats.score, 1200);
      expect(cubit.state.result?.summary.stats.accuracy, 100);
      expect(cubit.state.result?.sequencesCompleted, 3);
      expect(cubit.state.result?.perfectStages, 9);
      expect(cubit.state.result?.longestSequenceRemembered, 6);
      expect(cubit.state.result?.replayCount, 0);
      expect(cubit.state.result?.review, hasLength(9));

      await cubit.close();
    });

    test('pause and restart cancel pending audio safely', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      await _settle();
      cubit.pause();
      await _settle();
      expect(audio.pauseCount, 1);
      audio.complete();
      await _settle();

      expect(cubit.state.stage, SequencingStage.paused);

      cubit.resume();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);
      audio.complete();
      await _settle();
      expect(cubit.state.stage, SequencingStage.arrangePartOne);

      final int stalePlaybackId = audio.activePlaybackId;
      cubit.restart();
      await _settle();
      audio.complete(playbackId: stalePlaybackId);
      await _settle();

      expect(cubit.state.stage, SequencingStage.listenPartOne);
      expect(cubit.state.currentRound?.roundId, 1);
      expect(cubit.state.review, isEmpty);
      expect(audio.stopCount, greaterThanOrEqualTo(1));

      await cubit.close();
    });
  });

  _addFailsafeTests();
}

class _ControlledAudioService implements SequencingAudioService {
  final StreamController<SequencingAudioProgress> _progress =
      StreamController<SequencingAudioProgress>.broadcast();

  int plays = 0;
  int stopCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int activePlaybackId = 0;
  int itemCount = 0;
  bool _isSpeaking = false;

  @override
  Stream<SequencingAudioProgress> get progress => _progress.stream;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  int speakItem(String item) => speakSequence(<String>[item]);

  @override
  int speakSequence(List<String> items) {
    plays += 1;
    activePlaybackId += 1;
    itemCount = items.length;
    _isSpeaking = true;
    return activePlaybackId;
  }

  void emitCurrentItem(String item, {int? playbackId}) {
    _progress.add(
      SequencingAudioProgress(
        playbackId: playbackId ?? activePlaybackId,
        spokenCount: 0,
        currentItemIndex: 0,
        currentItem: item,
      ),
    );
  }

  void complete({int? playbackId}) {
    _isSpeaking = false;
    _progress.add(
      SequencingAudioProgress(
        playbackId: playbackId ?? activePlaybackId,
        spokenCount: itemCount,
        currentItemIndex: itemCount,
        isComplete: true,
      ),
    );
  }

  void emitError({int? playbackId, String message = 'tts_crash'}) {
    _isSpeaking = false;
    _progress.add(
      SequencingAudioProgress(
        playbackId: playbackId ?? activePlaybackId,
        spokenCount: 0,
        currentItemIndex: 0,
        errorMessage: message,
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    if (_isSpeaking) {
      _isSpeaking = false;
      _progress.add(
        SequencingAudioProgress(
          playbackId: activePlaybackId,
          spokenCount: 0,
          currentItemIndex: 0,
          isCancelled: true,
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
    await stop();
  }

  @override
  Future<void> resume() async {
    resumeCount += 1;
  }

  @override
  Future<void> dispose() async {
    await _progress.close();
  }
}

// ---------------------------------------------------------------------------
// Failsafe tests
// ---------------------------------------------------------------------------

// Cubit factory using an extremely short failsafe so tests do not wait seconds.
SequencingMemoryCubit _cubitWithFailsafe(
  _ControlledAudioService audio, {
  Duration perItem = const Duration(milliseconds: 40),
  Duration base = const Duration(milliseconds: 20),
}) {
  return SequencingMemoryCubit(
    audioService: audio,
    listenFailsafePerItem: perItem,
    listenFailsafeBase: base,
  );
}

void _addFailsafeTests() {
  group('TTS listen failsafe', () {
    test('audio error advances to arrange immediately without waiting for failsafe',
        () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = _cubitWithFailsafe(audio);

      cubit.start();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);

      audio.emitError(message: 'tts_engine_crash');
      await _settle();

      expect(cubit.state.stage, SequencingStage.arrangePartOne);
      expect(cubit.state.currentCards, hasLength(3));

      await cubit.close();
    });

    test('failsafe fires when audio completion never arrives', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = _cubitWithFailsafe(audio);

      cubit.start();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);

      // Do NOT call audio.complete() — let the failsafe timer fire.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(cubit.state.stage, SequencingStage.arrangePartOne);
      expect(cubit.state.currentCards, hasLength(3));

      await cubit.close();
    });

    test('normal audio completion cancels failsafe — no double advance', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      // Short failsafe, but complete fires first.
      final SequencingMemoryCubit cubit = _cubitWithFailsafe(
        audio,
        base: const Duration(milliseconds: 200),
        perItem: const Duration(milliseconds: 200),
      );

      cubit.start();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);

      // Complete before failsafe fires.
      audio.complete();
      await _settle();

      expect(cubit.state.stage, SequencingStage.arrangePartOne);

      // Wait past failsafe window; stage must not change again.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(cubit.state.stage, SequencingStage.arrangePartOne);

      await cubit.close();
    });

    test('pause cancels failsafe; game stays paused and does not auto-advance',
        () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = _cubitWithFailsafe(
        audio,
        base: const Duration(milliseconds: 150),
        perItem: const Duration(milliseconds: 100),
      );

      cubit.start();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);

      cubit.pause();
      await _settle();
      expect(cubit.state.stage, SequencingStage.paused);

      // Wait well past the failsafe window; must remain paused.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(cubit.state.stage, SequencingStage.paused);

      await cubit.close();
    });

    test('resume after pause reschedules the failsafe', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = _cubitWithFailsafe(audio);

      cubit.start();
      await _settle();

      cubit.pause();
      await _settle();
      expect(cubit.state.stage, SequencingStage.paused);

      // Simulate delay during pause — failsafe must not have fired.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(cubit.state.stage, SequencingStage.paused);

      // Resume — should re-enter listening and reschedule failsafe.
      cubit.resume();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);

      // New failsafe fires after another short delay without audio completion.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(cubit.state.stage, SequencingStage.arrangePartOne);

      await cubit.close();
    });

    test('restart resets pending failsafe; new session works from scratch',
        () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      // Use default short values (base=20ms, perItem=40ms → fires in ~140ms)
      // so the new-session failsafe arrives well within the 300ms wait below.
      final SequencingMemoryCubit cubit = _cubitWithFailsafe(audio);

      cubit.start();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);

      // Restart before the failsafe fires.
      cubit.restart();
      await _settle();

      // Stale failsafe must not have advanced the new round.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      // New failsafe will have fired by now and advanced to arrange.
      expect(cubit.state.stage, SequencingStage.arrangePartOne);
      // It must be round 1 of the fresh session.
      expect(cubit.state.currentRound?.roundId, 1);
      expect(cubit.state.currentChallengeIndex, 1);

      await cubit.close();
    });

    test('dispose does not emit after close', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = _cubitWithFailsafe(
        audio,
        base: const Duration(milliseconds: 50),
        perItem: const Duration(milliseconds: 50),
      );

      cubit.start();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);

      // Close while in listening stage — failsafe timer and subscription must
      // be cancelled so nothing emits after close.
      await cubit.close();

      // Wait past the would-have-fired window — no assertion errors expected.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    test('stale playback id from a previous round does not advance new round',
        () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = _cubitWithFailsafe(audio);

      cubit.start();
      await _settle();
      final int stalePlaybackId = audio.activePlaybackId;

      // Advance normally to part two.
      audio.complete();
      await _settle();
      _submitPerfect(cubit);
      cubit.continueAfterFeedback();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartTwo);

      // Deliver a late completion for the stale part one playback id.
      audio.complete(playbackId: stalePlaybackId);
      await _settle();

      // Must remain in listenPartTwo, not advance twice.
      expect(cubit.state.stage, SequencingStage.listenPartTwo);

      await cubit.close();
    });

    test(
      'failsafe fires for listenPartTwo when part one completed normally',
      () async {
        final _ControlledAudioService audio = _ControlledAudioService();
        final SequencingMemoryCubit cubit = _cubitWithFailsafe(audio);

        cubit.start();
        await _settle();

        // Part one completes normally.
        audio.complete();
        await _settle();
        _submitPerfect(cubit);
        cubit.continueAfterFeedback();
        await _settle();
        expect(cubit.state.stage, SequencingStage.listenPartTwo);

        // Part two TTS hangs — failsafe should advance to arrangePartTwo.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(cubit.state.stage, SequencingStage.arrangePartTwo);

        await cubit.close();
      },
    );
  });
}

void _submitPerfect(SequencingMemoryCubit cubit) {
  _reorderTo(cubit, cubit.state.currentItems);
  cubit.submitCurrentOrder();
}

void _reorderTo(SequencingMemoryCubit cubit, List<String> desiredOrder) {
  final List<String> local = cubit.state.currentCards.toList();
  for (
    int targetIndex = 0;
    targetIndex < desiredOrder.length;
    targetIndex += 1
  ) {
    final int oldIndex = local.indexOf(desiredOrder[targetIndex]);
    if (oldIndex == targetIndex) {
      continue;
    }
    cubit.reorderCards(oldIndex, targetIndex);
    final String moved = local.removeAt(oldIndex);
    local.insert(targetIndex, moved);
  }
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
