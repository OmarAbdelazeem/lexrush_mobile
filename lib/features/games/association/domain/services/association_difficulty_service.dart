import 'package:lexrush/features/games/association/domain/entities/association_difficulty.dart';

class AssociationDifficultyService {
  const AssociationDifficultyService();

  static const int beginnerRoundCount = 5;
  static const int hardPhaseSeconds = 15;

  AssociationDifficulty difficultyFor({
    required int nextRoundId,
    required int secondsLeft,
    required int wordsSolved,
  }) {
    if (nextRoundId <= beginnerRoundCount) {
      return AssociationDifficulty.easy;
    }
    if (secondsLeft <= hardPhaseSeconds) {
      return AssociationDifficulty.hard;
    }
    if (secondsLeft >= _easyFloorSeconds) {
      return AssociationDifficulty.easy;
    }
    if (wordsSolved >= _mediumWordsThreshold ||
        secondsLeft <= _mediumWindowSeconds) {
      return AssociationDifficulty.medium;
    }
    return AssociationDifficulty.easy;
  }

  static const int _easyFloorSeconds = 40;
  static const int _mediumWindowSeconds = 30;
  static const int _mediumWordsThreshold = 10;

  Duration roundWindowFor({
    required int nextRoundId,
    required AssociationDifficulty difficulty,
  }) {
    if (nextRoundId <= beginnerRoundCount) {
      return const Duration(milliseconds: 5000);
    }
    switch (difficulty) {
      case AssociationDifficulty.easy:
        return const Duration(milliseconds: 4200);
      case AssociationDifficulty.medium:
        return const Duration(milliseconds: 3400);
      case AssociationDifficulty.hard:
        return const Duration(milliseconds: 2800);
    }
  }
}
