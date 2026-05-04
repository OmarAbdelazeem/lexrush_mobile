import 'dart:math';

import 'package:lexrush/features/games/association/domain/entities/association_difficulty.dart';
import 'package:lexrush/features/games/association/domain/entities/association_option.dart';
import 'package:lexrush/features/games/association/domain/entities/association_prompt.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round.dart';
import 'package:lexrush/features/games/association/domain/services/association_difficulty_service.dart';

class AssociationRoundGenerator {
  AssociationRoundGenerator({
    required List<AssociationPrompt> prompts,
    Random? random,
    AssociationDifficultyService difficultyService =
        const AssociationDifficultyService(),
  }) : _allPrompts = prompts,
       _random = random ?? Random(),
       _difficultyService = difficultyService;

  final List<AssociationPrompt> _allPrompts;
  final Random _random;
  final AssociationDifficultyService _difficultyService;
  final Map<AssociationDifficulty, List<AssociationPrompt>> _queues =
      <AssociationDifficulty, List<AssociationPrompt>>{};
  final List<AssociationPrompt> _beginnerQueue = <AssociationPrompt>[];
  int _roundId = 0;

  int get nextRoundId => _roundId + 1;

  void reset() {
    _roundId = 0;
    _queues.clear();
    _beginnerQueue.clear();
  }

  AssociationRound generate({
    required int secondsLeft,
    required int wordsSolved,
    DateTime? now,
  }) {
    final int roundId = ++_roundId;
    final AssociationDifficulty difficulty = _difficultyService.difficultyFor(
      nextRoundId: roundId,
      secondsLeft: secondsLeft,
      wordsSolved: wordsSolved,
    );
    final AssociationPrompt prompt =
        roundId <= AssociationDifficultyService.beginnerRoundCount
        ? _nextBeginnerPrompt()
        : _nextPrompt(difficulty);
    final List<AssociationOption> options = <AssociationOption>[
      AssociationOption(
        id: '${roundId}_correct',
        word: prompt.correctAnswer,
        isCorrect: true,
      ),
      AssociationOption(
        id: '${roundId}_wrong',
        word: prompt.wrongAnswer,
        isCorrect: false,
      ),
    ]..shuffle(_random);

    return AssociationRound(
      roundId: roundId,
      targetWord: prompt.targetWord,
      correctAnswer: prompt.correctAnswer,
      explanation: prompt.explanation,
      type: prompt.type,
      difficulty: prompt.difficulty,
      options: options,
      startedAt: now ?? DateTime.now(),
      contextHint: prompt.contextHint,
    );
  }

  Duration roundWindowFor(AssociationRound round) {
    return _difficultyService.roundWindowFor(
      nextRoundId: round.roundId,
      difficulty: round.difficulty,
    );
  }

  AssociationPrompt _nextBeginnerPrompt() {
    if (_beginnerQueue.isEmpty) {
      _beginnerQueue
        ..clear()
        ..addAll(
          _allPrompts
              .where((AssociationPrompt prompt) => prompt.beginnerSafe)
              .toList()
            ..shuffle(_random),
        );
    }
    return _beginnerQueue.removeAt(0);
  }

  AssociationPrompt _nextPrompt(AssociationDifficulty difficulty) {
    final List<AssociationPrompt> queue = _queues.putIfAbsent(
      difficulty,
      () => <AssociationPrompt>[],
    );
    if (queue.isEmpty) {
      queue
        ..clear()
        ..addAll(_eligiblePromptsFor(difficulty)..shuffle(_random));
    }
    return queue.removeAt(0);
  }

  List<AssociationPrompt> _eligiblePromptsFor(
    AssociationDifficulty difficulty,
  ) {
    final List<AssociationPrompt> matches = _allPrompts
        .where((AssociationPrompt prompt) => prompt.difficulty == difficulty)
        .toList();
    if (matches.isNotEmpty) {
      return matches;
    }
    return _allPrompts
        .where(
          (AssociationPrompt prompt) =>
              prompt.difficulty != AssociationDifficulty.hard,
        )
        .toList();
  }
}
