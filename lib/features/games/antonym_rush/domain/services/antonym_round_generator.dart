import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_difficulty.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_pair.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/balloon_option.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_round.dart';
import 'package:lexrush/features/games/antonym_rush/domain/services/antonym_difficulty_service.dart';
import 'package:lexrush/shared/domain/entities/difficulty_phase.dart';

class AntonymRoundGenerator {
  AntonymRoundGenerator({
    required this.pairs,
    required this.difficultyService,
    Random? random,
  }) : _random = random ?? Random();

  final List<AntonymPair> pairs;
  final AntonymDifficultyService difficultyService;
  final Random _random;
  List<int> _queue = <int>[];
  int _roundId = 0;
  int _optionId = 0;

  void reset() {
    debugPrint('[AntonymRoundGenerator] reset');
    _queue = <int>[];
    _roundId = 0;
    _optionId = 0;
  }

  AntonymRound generate({
    required int timeLeft,
    required int wordsSolved,
  }) {
    final phase = difficultyService.phaseForTimeLeft(timeLeft);
    final AntonymPair pair = _nextPair(
      phase: phase,
      timeLeft: timeLeft,
      wordsSolved: wordsSolved,
    );
    final List<String> answers = <String>[pair.antonym, ...pair.distractors]..shuffle(_random);
    final List<BalloonOption> options = answers
        .map(
          (String answer) => BalloonOption(
            id: 'option-${++_optionId}',
            word: answer,
            isCorrect: answer == pair.antonym,
          ),
        )
        .toList(growable: false);
    final AntonymRound round = AntonymRound(
      roundId: ++_roundId,
      targetWord: pair.word,
      correctAnswer: pair.antonym,
      pairDifficulty: pair.difficulty,
      options: options,
      startedAt: DateTime.now(),
    );
    debugPrint('[AntonymRoundGenerator] round=${round.roundId} word=${pair.word} phase=$phase');
    return round;
  }

  AntonymPair _nextPair({
    required DifficultyPhase phase,
    required int timeLeft,
    required int wordsSolved,
  }) {
    final allowed = difficultyService.allowedForPhase(phase);
    List<AntonymDifficulty> preferred = difficultyService.preferredForPhase(phase);
    if (timeLeft > 15) {
      preferred = preferred.where((d) => d != AntonymDifficulty.hard).toList(growable: false);
    }
    if (wordsSolved < 5) {
      preferred = const <AntonymDifficulty>[
        AntonymDifficulty.easy,
        AntonymDifficulty.easy,
        AntonymDifficulty.easy,
        AntonymDifficulty.medium,
      ];
    }
    if (_queue.isEmpty) {
      _queue = List<int>.generate(pairs.length, (int index) => index)..shuffle(_random);
    }
    final preferredDifficulty = preferred[_random.nextInt(preferred.length)];
    final allowedIndices = pairs
        .asMap()
        .entries
        .where((entry) => allowed.contains(entry.value.difficulty))
        .map((entry) => entry.key)
        .toSet();
    final preferredIndices = pairs
        .asMap()
        .entries
        .where((entry) => entry.value.difficulty == preferredDifficulty)
        .map((entry) => entry.key)
        .toSet();
    final eligible = preferredIndices.isNotEmpty ? preferredIndices : allowedIndices;
    final int queueIndex = _queue.indexWhere((int idx) => eligible.contains(idx));
    if (queueIndex >= 0) {
      final int selected = _queue.removeAt(queueIndex);
      return pairs[selected];
    }
    return pairs.firstWhere((pair) => allowed.contains(pair.difficulty));
  }
}
