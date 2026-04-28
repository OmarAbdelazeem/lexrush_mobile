import 'package:flutter/foundation.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_difficulty.dart';
import 'package:lexrush/shared/domain/entities/difficulty_phase.dart';

class AntonymDifficultyService {
  const AntonymDifficultyService();

  DifficultyPhase phaseForTimeLeft(int secondsLeft) {
    if (secondsLeft > 40) return DifficultyPhase.early;
    if (secondsLeft > 15) return DifficultyPhase.mid;
    return DifficultyPhase.late;
  }

  List<AntonymDifficulty> allowedForPhase(DifficultyPhase phase) {
    switch (phase) {
      case DifficultyPhase.early:
      case DifficultyPhase.mid:
        return const <AntonymDifficulty>[
          AntonymDifficulty.easy,
          AntonymDifficulty.medium,
        ];
      case DifficultyPhase.late:
        return const <AntonymDifficulty>[
          AntonymDifficulty.medium,
          AntonymDifficulty.hard,
        ];
    }
  }

  List<AntonymDifficulty> preferredForPhase(DifficultyPhase phase) {
    switch (phase) {
      case DifficultyPhase.early:
        return const <AntonymDifficulty>[
          AntonymDifficulty.easy,
          AntonymDifficulty.easy,
          AntonymDifficulty.easy,
          AntonymDifficulty.medium,
        ];
      case DifficultyPhase.mid:
        return const <AntonymDifficulty>[
          AntonymDifficulty.medium,
          AntonymDifficulty.medium,
          AntonymDifficulty.medium,
          AntonymDifficulty.easy,
        ];
      case DifficultyPhase.late:
        return const <AntonymDifficulty>[
          AntonymDifficulty.medium,
          AntonymDifficulty.medium,
          AntonymDifficulty.hard,
          AntonymDifficulty.hard,
        ];
    }
  }

  double speedFor({
    required DifficultyPhase phase,
    required int wordsSolved,
  }) {
    final int clampedWordsSolved = wordsSolved.clamp(0, 18);
    final double speed;
    switch (phase) {
      case DifficultyPhase.early:
        speed = (5.3 - clampedWordsSolved * 0.04).clamp(4.5, 5.3);
      case DifficultyPhase.mid:
        speed = (4.5 - clampedWordsSolved * 0.035).clamp(3.8, 4.5);
      case DifficultyPhase.late:
        speed = (3.9 - clampedWordsSolved * 0.03).clamp(3.1, 3.9);
    }
    debugPrint('[AntonymDifficultyService] phase=$phase wordsSolved=$wordsSolved speed=$speed');
    return speed;
  }
}
