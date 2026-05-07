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
