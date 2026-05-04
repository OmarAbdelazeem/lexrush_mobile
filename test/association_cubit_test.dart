import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/association/application/cubit/association_cubit.dart';
import 'package:lexrush/features/games/association/application/cubit/association_state.dart';
import 'package:lexrush/features/games/association/data/association_prompts.dart';
import 'package:lexrush/features/games/association/domain/entities/association_difficulty.dart';
import 'package:lexrush/features/games/association/domain/entities/association_option.dart';
import 'package:lexrush/features/games/association/domain/entities/association_outcome.dart';
import 'package:lexrush/features/games/association/domain/entities/association_prompt.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round.dart';
import 'package:lexrush/features/games/association/domain/entities/association_type.dart';
import 'package:lexrush/features/games/association/domain/services/association_difficulty_service.dart';
import 'package:lexrush/features/games/association/domain/services/association_round_generator.dart';

void main() {
  group('AssociationDifficultyService', () {
    const AssociationDifficultyService service = AssociationDifficultyService();

    test('first 5 rounds always return easy', () {
      for (int id = 1; id <= 5; id += 1) {
        expect(
          service.difficultyFor(
            nextRoundId: id,
            secondsLeft: 20,
            wordsSolved: 99,
          ),
          AssociationDifficulty.easy,
        );
      }
    });

    test(
      'first 20 seconds (secondsLeft >= 40) stays easy regardless of wordsSolved',
      () {
        for (int seconds = 60; seconds >= 40; seconds -= 1) {
          for (final int wordsSolved in <int>[0, 5, 10, 25]) {
            expect(
              service.difficultyFor(
                nextRoundId: 6,
                secondsLeft: seconds,
                wordsSolved: wordsSolved,
              ),
              AssociationDifficulty.easy,
              reason:
                  'secondsLeft=$seconds wordsSolved=$wordsSolved should be easy',
            );
          }
        }
      },
    );

    test('mid window can return medium when threshold met', () {
      expect(
        service.difficultyFor(
          nextRoundId: 6,
          secondsLeft: 35,
          wordsSolved: 12,
        ),
        AssociationDifficulty.medium,
      );
      expect(
        service.difficultyFor(
          nextRoundId: 6,
          secondsLeft: 25,
          wordsSolved: 0,
        ),
        AssociationDifficulty.medium,
      );
    });

    test('hard window stays hard at 15 seconds and below', () {
      for (final int seconds in <int>[15, 10, 5, 1]) {
        expect(
          service.difficultyFor(
            nextRoundId: 6,
            secondsLeft: seconds,
            wordsSolved: 0,
          ),
          AssociationDifficulty.hard,
        );
      }
    });
  });

  group('AssociationRoundGenerator', () {
    test('returns exactly 2 options and exactly 1 correct option', () {
      final AssociationRoundGenerator generator = AssociationRoundGenerator(
        prompts: associationPrompts,
      );

      final AssociationRound round = generator.generate(
        secondsLeft: 60,
        wordsSolved: 0,
      );

      expect(round.options, hasLength(2));
      expect(
        round.options.where((AssociationOption option) => option.isCorrect),
        hasLength(1),
      );
    });

    test('first 5 rounds use beginner-safe prompts', () {
      final AssociationRoundGenerator generator = AssociationRoundGenerator(
        prompts: associationPrompts,
      );
      final Set<String> beginnerTargets = associationPrompts
          .where((prompt) => prompt.beginnerSafe)
          .map((prompt) => prompt.targetWord)
          .toSet();

      for (int i = 1; i <= 5; i += 1) {
        final AssociationRound round = generator.generate(
          secondsLeft: 60,
          wordsSolved: i - 1,
        );
        expect(beginnerTargets, contains(round.targetWord));
        expect(round.options, hasLength(2));
      }
    });

    test('hard prompts do not appear before final 15 seconds', () {
      final AssociationRoundGenerator generator = AssociationRoundGenerator(
        prompts: associationPrompts,
      );

      for (int i = 1; i <= 12; i += 1) {
        final AssociationRound round = generator.generate(
          secondsLeft: 16,
          wordsSolved: 20,
        );
        expect(round.difficulty, isNot(AssociationDifficulty.hard));
      }
    });

    test('context hints are hard-only and carried into generated rounds', () {
      final List<AssociationPrompt> contextualPrompts = associationPrompts
          .where((AssociationPrompt prompt) => prompt.contextHint != null)
          .toList();
      final AssociationRoundGenerator generator = AssociationRoundGenerator(
        prompts: <AssociationPrompt>[
          const AssociationPrompt(
            targetWord: 'plain',
            correctAnswer: 'simple',
            wrongAnswer: 'stormy',
            explanation: 'Simple is closest to plain.',
            type: AssociationType.synonymMatch,
            difficulty: AssociationDifficulty.easy,
            beginnerSafe: true,
          ),
          contextualPrompts.first,
        ],
      );

      for (int i = 0; i < 5; i += 1) {
        generator.generate(secondsLeft: 60, wordsSolved: i);
      }
      final AssociationRound round = generator.generate(
        secondsLeft: 10,
        wordsSolved: 20,
      );

      expect(contextualPrompts, isNotEmpty);
      expect(
        associationPrompts.where(
          (AssociationPrompt prompt) =>
              prompt.contextHint != null &&
              prompt.difficulty != AssociationDifficulty.hard,
        ),
        isEmpty,
      );
      expect(round.contextHint, contextualPrompts.first.contextHint);
      expect(round.difficulty, AssociationDifficulty.hard);
    });
  });

  group('AssociationCubit', () {
    test('correct tap increments score, words, combo, and review', () async {
      final AssociationCubit cubit = AssociationCubit();

      cubit.start();
      final AssociationRound round = cubit.state.currentRound!;
      final AssociationOption correct = round.options.firstWhere(
        (AssociationOption option) => option.isCorrect,
      );

      cubit.submitAnswer(correct.id);

      expect(cubit.state.status, AssociationStatus.feedback);
      expect(cubit.state.score, 100);
      expect(cubit.state.wordsSolved, 1);
      expect(cubit.state.combo, 1);
      expect(cubit.state.review, hasLength(1));
      expect(cubit.state.review.single.outcome, AssociationOutcome.correct);

      await cubit.close();
    });

    test(
      'wrong tap applies -3s, resets combo, records review, blocks taps',
      () async {
        final AssociationCubit cubit = AssociationCubit();

        cubit.start();
        final AssociationRound round = cubit.state.currentRound!;
        final AssociationOption wrong = round.options.firstWhere(
          (AssociationOption option) => !option.isCorrect,
        );

        cubit.submitAnswer(wrong.id);
        final int timeAfterWrong = cubit.state.timeLeft;
        final int attemptsAfterWrong = cubit.state.totalAttempts;

        cubit.submitAnswer(wrong.id);

        expect(cubit.state.status, AssociationStatus.feedback);
        expect(timeAfterWrong, 57);
        expect(cubit.state.combo, 0);
        expect(cubit.state.totalAttempts, attemptsAfterWrong);
        expect(cubit.state.review.single.outcome, AssociationOutcome.wrong);
        expect(cubit.state.review.single.explanation, isNotEmpty);

        await cubit.close();
      },
    );

    test('wrong feedback advances by tap to continue', () async {
      final AssociationCubit cubit = AssociationCubit();

      cubit.start();
      final AssociationRound round = cubit.state.currentRound!;
      final AssociationOption wrong = round.options.firstWhere(
        (AssociationOption option) => !option.isCorrect,
      );

      cubit.submitAnswer(wrong.id);
      cubit.continueAfterFeedback();

      expect(cubit.state.status, AssociationStatus.playing);
      expect(cubit.state.currentRound?.roundId, 2);

      await cubit.close();
    });

    test('restart cancels stale feedback transition timers', () async {
      final AssociationCubit cubit = AssociationCubit();

      cubit.start();
      final AssociationRound round = cubit.state.currentRound!;
      final AssociationOption wrong = round.options.firstWhere(
        (AssociationOption option) => !option.isCorrect,
      );

      cubit.submitAnswer(wrong.id);
      cubit.restart();
      await Future<void>.delayed(const Duration(milliseconds: 1900));

      expect(cubit.state.status, AssociationStatus.playing);
      expect(cubit.state.currentRound?.roundId, 1);
      expect(cubit.state.review, isEmpty);

      await cubit.close();
    });

    test('pause blocks feedback auto-continue until resume', () async {
      final AssociationCubit cubit = AssociationCubit();

      cubit.start();
      final AssociationRound round = cubit.state.currentRound!;
      final AssociationOption wrong = round.options.firstWhere(
        (AssociationOption option) => !option.isCorrect,
      );

      cubit.submitAnswer(wrong.id);
      cubit.pause();
      await Future<void>.delayed(const Duration(milliseconds: 1900));

      expect(cubit.state.status, AssociationStatus.paused);
      expect(cubit.state.currentRound?.roundId, 1);

      cubit.resume();
      expect(cubit.state.status, AssociationStatus.feedback);
      await Future<void>.delayed(const Duration(milliseconds: 1900));

      expect(cubit.state.status, AssociationStatus.playing);
      expect(cubit.state.currentRound?.roundId, 2);

      await cubit.close();
    });

    test('pause blocks active round timeout until resume', () async {
      final AssociationCubit cubit = AssociationCubit(
        roundGenerator: AssociationRoundGenerator(
          prompts: associationPrompts,
          difficultyService: const _FastAssociationDifficultyService(),
        ),
      );

      cubit.start();
      cubit.pause();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.status, AssociationStatus.paused);
      expect(cubit.state.missedWords, 0);

      cubit.resume();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.status, AssociationStatus.feedback);
      expect(cubit.state.lastOutcome, AssociationOutcome.missed);
      expect(cubit.state.missedWords, 1);

      await cubit.close();
    });

    test('end game builds review-capable result with honest stats', () async {
      final AssociationCubit cubit = AssociationCubit();

      cubit.start();
      final AssociationRound round = cubit.state.currentRound!;
      final AssociationOption correct = round.options.firstWhere(
        (AssociationOption option) => option.isCorrect,
      );
      cubit.submitAnswer(correct.id);
      cubit.endGame();

      expect(cubit.state.status, AssociationStatus.finished);
      expect(cubit.state.result, isNotNull);
      expect(cubit.state.result?.summary.stats.score, 100);
      expect(cubit.state.result?.summary.stats.accuracy, 100);
      expect(cubit.state.result?.summary.stats.wordsSolved, 1);
      expect(cubit.state.result?.review, hasLength(1));

      await cubit.close();
    });
  });
}

class _FastAssociationDifficultyService extends AssociationDifficultyService {
  const _FastAssociationDifficultyService();

  @override
  Duration roundWindowFor({
    required int nextRoundId,
    required AssociationDifficulty difficulty,
  }) {
    return const Duration(milliseconds: 20);
  }
}
