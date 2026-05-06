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

      expect(cubit.state.currentChallengeIndex, 1);
      expect(cubit.state.totalChallenges, 3);
      expect(cubit.state.stage, SequencingStage.listenPartOne);
      expect(cubit.state.currentRound?.roundId, 1);
      expect(cubit.state.currentCards, isEmpty);
      expect(audio.plays, 1);

      await cubit.close();
    });

    test(
      'mock audio completion advances to arrange without exposing cards early',
      () async {
        final _ControlledAudioService audio = _ControlledAudioService();
        final SequencingMemoryCubit cubit = SequencingMemoryCubit(
          audioService: audio,
        );

        cubit.start();
        expect(cubit.state.currentCards, isEmpty);

        audio.playback.complete();

        expect(cubit.state.stage, SequencingStage.arrangePartOne);
        expect(cubit.state.currentCards, hasLength(3));
        expect(cubit.state.spokenProgress, 3);

        await cubit.close();
      },
    );

    test('reorder plus perfect submit scores a part correctly', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      audio.playback.complete();
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
      audio.playback.complete();
      final List<String> target = cubit.state.currentItems;
      _reorderTo(cubit, <String>[target[0], target[2], target[1]]);
      cubit.submitCurrentOrder();

      expect(cubit.state.score, 20);
      expect(cubit.state.lastResult?.correctPositions, 1);
      expect(cubit.state.lastResult?.pointsEarned, 20);
      expect(cubit.state.perfectStages, 0);

      await cubit.close();
    });

    test('replay increments once per part and returns to listening', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      audio.playback.complete();

      cubit.replayCurrentPart();
      expect(cubit.state.stage, SequencingStage.listenPartOne);
      expect(cubit.state.replayCount, 1);
      expect(cubit.state.stageReplayCount, 1);

      audio.playback.complete();
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
      audio.playback.complete();
      _submitPerfect(cubit);
      cubit.continueAfterFeedback();

      expect(cubit.state.stage, SequencingStage.listenPartTwo);
      audio.playback.complete();
      _submitPerfect(cubit);
      cubit.continueAfterFeedback();

      expect(cubit.state.stage, SequencingStage.arrangeCombined);
      expect(cubit.state.currentItems, hasLength(6));
      _submitPerfect(cubit);

      expect(cubit.state.stage, SequencingStage.feedbackCombined);
      expect(cubit.state.score, 400);

      await cubit.close();
    });

    test('final result computes honest sequencing metrics', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      for (int challenge = 0; challenge < 3; challenge += 1) {
        audio.playback.complete();
        _submitPerfect(cubit);
        cubit.continueAfterFeedback();
        audio.playback.complete();
        _submitPerfect(cubit);
        cubit.continueAfterFeedback();
        _submitPerfect(cubit);
        cubit.continueAfterFeedback();
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

    test('pause and restart keep pending audio callbacks safe', () async {
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
      );

      cubit.start();
      cubit.pause();
      expect(audio.playback.paused, isTrue);
      audio.playback.complete();

      expect(cubit.state.stage, SequencingStage.paused);

      cubit.resume();
      expect(audio.playback.paused, isFalse);
      audio.playback.complete();
      expect(cubit.state.stage, SequencingStage.arrangePartOne);

      final _ControlledPlayback stalePlayback = audio.playback;
      cubit.restart();
      stalePlayback.complete();

      expect(cubit.state.stage, SequencingStage.listenPartOne);
      expect(cubit.state.currentRound?.roundId, 1);
      expect(cubit.state.review, isEmpty);

      await cubit.close();
    });
  });
}

class _ControlledAudioService implements SequencingAudioService {
  int plays = 0;
  late _ControlledPlayback playback;

  @override
  SequencingAudioPlayback playSequence({
    required List<String> items,
    required void Function(int spokenCount) onProgress,
    required void Function() onComplete,
  }) {
    plays += 1;
    onProgress(0);
    playback = _ControlledPlayback(
      itemCount: items.length,
      onProgress: onProgress,
      onComplete: onComplete,
    );
    return playback;
  }
}

class _ControlledPlayback implements SequencingAudioPlayback {
  _ControlledPlayback({
    required this.itemCount,
    required this.onProgress,
    required this.onComplete,
  });

  final int itemCount;
  final void Function(int spokenCount) onProgress;
  final void Function() onComplete;
  bool paused = false;
  bool cancelled = false;

  void complete() {
    if (cancelled) {
      return;
    }
    onProgress(itemCount);
    onComplete();
  }

  @override
  void cancel() {
    cancelled = true;
  }

  @override
  void pause() {
    paused = true;
  }

  @override
  void resume() {
    paused = false;
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
