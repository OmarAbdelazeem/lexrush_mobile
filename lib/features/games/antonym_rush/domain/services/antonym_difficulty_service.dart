import 'package:flutter/foundation.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_difficulty.dart';
import 'package:lexrush/shared/domain/entities/difficulty_phase.dart';

class AntonymDifficultyService {
  const AntonymDifficultyService();

  static const double _earlySpeedStart = 3.75;
  static const double _earlySpeedMin = 3.25;
  static const double _midSpeedStart = 3.10;
  static const double _midSpeedMin = 2.65;
  static const double _lateSpeedStart = 2.45;
  static const double _lateSpeedMin = 2.05;

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
        speed = (_earlySpeedStart - clampedWordsSolved * 0.018).clamp(
          _earlySpeedMin,
          _earlySpeedStart,
        );
      case DifficultyPhase.mid:
        speed = (_midSpeedStart - clampedWordsSolved * 0.017).clamp(
          _midSpeedMin,
          _midSpeedStart,
        );
      case DifficultyPhase.late:
        speed = (_lateSpeedStart - clampedWordsSolved * 0.014).clamp(
          _lateSpeedMin,
          _lateSpeedStart,
        );
    }
    debugPrint('[AntonymDifficultyService] phase=$phase wordsSolved=$wordsSolved speed=$speed');
    return speed;
  }
}
