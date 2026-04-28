import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_state.dart';
import 'package:lexrush/features/games/antonym_rush/data/antonym_pairs.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_round.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/balloon_option.dart';

void main() {
  group('AntonymRushCubit lifecycle', () {
    test('start initializes playable state', () {
      final AntonymRushCubit cubit = AntonymRushCubit();

      cubit.start();

      expect(cubit.state.status, AntonymRushStatus.playing);
      expect(cubit.state.currentRound, isNotNull);
      expect(cubit.state.timeLeft, 60);
      cubit.close();
    });

    test('pause and resume preserve active session', () {
      final AntonymRushCubit cubit = AntonymRushCubit();

      cubit.start();
      cubit.pause();
      expect(cubit.state.status, AntonymRushStatus.paused);

      cubit.resume();
      expect(cubit.state.status, AntonymRushStatus.playing);
      expect(cubit.state.currentRound, isNotNull);
      cubit.close();
    });

    test('endGame emits ended with result', () {
      final AntonymRushCubit cubit = AntonymRushCubit();

      cubit.start();
      cubit.endGame();

      expect(cubit.state.status, AntonymRushStatus.ended);
      expect(cubit.state.gameResult, isNotNull);
      cubit.close();
    });
  });

  group('AntonymRushCubit beginner ramp', () {
    test(
      'rounds 1-5 use beginner-safe pairs, and every round uses 4 options',
      () async {
        final AntonymRushCubit cubit = AntonymRushCubit();
        final Set<String> beginnerTargets = antonymPairs
            .where((pair) => pair.beginnerSafe)
            .map((pair) => pair.word)
            .toSet();
        final List<String> firstFiveTargets = <String>[];

        cubit.start();

        for (
          int expectedRoundId = 1;
          expectedRoundId <= 5;
          expectedRoundId += 1
        ) {
          final AntonymRound round = cubit.state.currentRound!;
          expect(round.roundId, expectedRoundId);
          expect(round.options, hasLength(4));
          expect(beginnerTargets, contains(round.targetWord));
          expect(
            round.options.where((option) => option.isCorrect),
            hasLength(1),
          );
          firstFiveTargets.add(round.targetWord);

          final BalloonOption correct = round.options.firstWhere(
            (option) => option.isCorrect,
          );
          cubit.submitAnswer(correct.id);
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }

        final AntonymRound roundSix = cubit.state.currentRound!;
        expect(firstFiveTargets.toSet(), hasLength(5));
        expect(roundSix.roundId, 6);
        expect(roundSix.options, hasLength(4));

        await cubit.close();
      },
    );

    test('first 5 correct taps all score as correct with no misses', () async {
      final AntonymRushCubit cubit = AntonymRushCubit();

      cubit.start();

      for (
        int expectedRoundId = 1;
        expectedRoundId <= 5;
        expectedRoundId += 1
      ) {
        final AntonymRound round = cubit.state.currentRound!;
        final BalloonOption correct = round.options.firstWhere(
          (option) => option.isCorrect,
        );

        expect(round.roundId, expectedRoundId);
        expect(correct.word, round.correctAnswer);

        cubit.submitAnswer(correct.id);

        expect(cubit.state.lastOutcome, RoundOutcome.correct);
        expect(cubit.state.wordsSolved, expectedRoundId);
        expect(cubit.state.correctAnswers, expectedRoundId);
        expect(cubit.state.missedWords, 0);
        expect(cubit.state.wrongAnswers, 0);

        if (expectedRoundId < 5) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }

      expect(cubit.state.score, 700);
      cubit.endGame();
      expect(cubit.state.gameResult?.stats.accuracy, 100);
      expect(cubit.state.gameResult?.stats.wordsSolved, 5);
      expect(cubit.state.gameResult?.stats.missedWords, 0);

      await cubit.close();
    });

    test('tap during feedback transition is ignored', () {
      final AntonymRushCubit cubit = AntonymRushCubit();

      cubit.start();
      final AntonymRound round = cubit.state.currentRound!;
      final BalloonOption correct = round.options.firstWhere(
        (option) => option.isCorrect,
      );

      cubit.submitAnswer(correct.id);
      final int scoreAfterCorrect = cubit.state.score;
      final int wordsAfterCorrect = cubit.state.wordsSolved;

      cubit.submitAnswer(correct.id);

      expect(cubit.state.score, scoreAfterCorrect);
      expect(cubit.state.wordsSolved, wordsAfterCorrect);
      expect(cubit.state.lastOutcome, RoundOutcome.correct);

      cubit.close();
    });
  });
}
