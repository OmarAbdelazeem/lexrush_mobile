// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/commas/application/cubit/commas_cubit.dart';
import 'package:lexrush/features/games/commas/application/cubit/commas_state.dart';
import 'package:lexrush/features/games/commas/data/comma_prompts.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';
import 'package:lexrush/features/games/commas/domain/services/comma_round_generator.dart';

void main() {
  group('CommasCubit', () {
    test('start initializes a 60-second session and first beginner prompt', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);

        cubit.start();

        expect(cubit.state.status, CommasStatus.playing);
        expect(cubit.state.timeLeft, 60);
        expect(cubit.state.currentPrompt, isNotNull);
        expect(cubit.state.currentPrompt!.difficulty, CommaDifficulty.beginner);
        expect(cubit.state.tokens, isNotEmpty);
        expect(cubit.state.remainingCommaCount, 1);

        cubit.close();
      });
    });

    test('correct tap inserts comma and scores 100', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();

        cubit.submitGap(6);

        expect(cubit.state.score, 200);
        expect(cubit.state.correctTaps, 1);
        expect(cubit.state.placedCommaIndexes, contains(6));
        expect(cubit.state.tokens[6].commaPlacedAfter, isTrue);
        expect(cubit.state.status, CommasStatus.sentenceComplete);

        cubit.close();
      });
    });

    test('wrong tap subtracts 3 seconds and does not insert comma', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();

        cubit.submitGap(0);

        expect(cubit.state.score, 0);
        expect(cubit.state.timeLeft, 57);
        expect(cubit.state.wrongTaps, 1);
        expect(cubit.state.wrongGapIndexes, <int>[0]);
        expect(cubit.state.flashGapAfterTokenIndex, 0);
        expect(cubit.state.placedCommaIndexes, isEmpty);
        expect(cubit.state.status, CommasStatus.wrongFeedback);

        cubit.close();
      });
    });

    test('repeated correct-gap tap is ignored after comma is placed', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();

        cubit.submitGap(6);
        cubit.submitGap(6);

        expect(cubit.state.score, 200);
        expect(cubit.state.correctTaps, 1);
        expect(cubit.state.totalAttempts, 1);
        expect(cubit.state.review, hasLength(1));

        cubit.close();
      });
    });

    test('sentence completes only after all required commas are found', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();
        cubit.submitGap(6);
        async.elapse(const Duration(milliseconds: 851));

        expect(cubit.state.currentPrompt!.id, 'date_beginner_001');
        expect(cubit.state.remainingCommaCount, 1);
        expect(cubit.state.status, CommasStatus.playing);
        cubit.submitGap(2);

        expect(cubit.state.sentencesCompleted, 2);
        expect(cubit.state.score, 400);
        expect(cubit.state.review, hasLength(2));

        cubit.close();
      });
    });

    test('completion bonus is awarded once only', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();

        cubit.submitGap(6);
        final int completedScore = cubit.state.score;
        cubit.submitGap(1);
        cubit.submitGap(6);

        expect(completedScore, 200);
        expect(cubit.state.score, completedScore);
        expect(cubit.state.sentencesCompleted, 1);
        expect(cubit.state.review, hasLength(1));

        cubit.close();
      });
    });

    test('pending transition cancels cleanly when timer reaches zero', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();
        async.elapse(const Duration(seconds: 59));

        cubit.submitGap(6);
        expect(cubit.state.status, CommasStatus.sentenceComplete);
        async.elapse(const Duration(seconds: 1));

        expect(cubit.state.status, CommasStatus.completed);
        expect(cubit.state.result, isNotNull);
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.status, CommasStatus.completed);

        cubit.close();
      });
    });

    test('result stats and review calculate correctly', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();
        async.elapse(const Duration(seconds: 2));
        cubit.submitGap(0);
        async.elapse(const Duration(seconds: 1));
        cubit.submitGap(6);
        cubit.endGame();

        final result = cubit.state.result!;
        final stats = result.summary.stats;
        expect(stats.score, 200);
        expect(stats.accuracy, 50);
        expect(stats.totalAttempts, 2);
        expect(stats.correctAnswers, 1);
        expect(stats.wordsSolved, 1);
        expect(stats.missedWords, 1);
        expect(stats.averageResponseTimeMs, 3000);
        expect(result.review, hasLength(1));
        expect(
          result.review.single.prompt.correctTextWithCommas,
          contains(','),
        );
        expect(result.review.single.wrongGapIndexes, <int>[0]);

        cubit.close();
      });
    });

    test('gap logic uses afterTokenIndex instead of raw coordinates', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();

        final correctGapId =
            cubit.state.currentPrompt!.insertionPoints.single.afterTokenIndex;
        cubit.submitGap(correctGapId);

        expect(correctGapId, 6);
        expect(cubit.state.placedCommaIndexes, contains(correctGapId));
        expect(cubit.state.tokens[correctGapId].commaPlacedAfter, isTrue);

        cubit.close();
      });
    });

    test('timer ending completes the session', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();

        async.elapse(const Duration(seconds: 60));

        expect(cubit.state.status, CommasStatus.completed);
        expect(cubit.state.result, isNotNull);

        cubit.close();
      });
    });

    test('pause, resume, and restart clear timers safely', () {
      fakeAsync((FakeAsync async) {
        final CommasCubit cubit = _buildCubit(async);
        cubit.start();
        cubit.submitGap(6);

        cubit.pause();
        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.status, CommasStatus.paused);
        expect(cubit.state.currentPrompt!.id, 'location_beginner_001');

        cubit.resume();
        async.elapse(const Duration(milliseconds: 851));
        expect(cubit.state.currentPrompt!.id, 'date_beginner_001');

        cubit.restart();
        expect(cubit.state.score, 0);
        expect(cubit.state.timeLeft, 60);
        expect(cubit.state.review, isEmpty);
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.timeLeft, 59);

        cubit.close();
      });
    });
  });
}

CommasCubit _buildCubit(FakeAsync async) {
  return CommasCubit(
    roundGenerator: CommaRoundGenerator(prompts: commaPrompts),
    clock: () => DateTime(2026, 5, 7).add(async.elapsed),
  );
}
