import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';

class CommaDifficultyService {
  const CommaDifficultyService();

  CommaDifficulty difficultyFor({
    required int completedPrompts,
    required int timeLeft,
  }) {
    if (completedPrompts < 5) return CommaDifficulty.beginner;
    if (completedPrompts < 10 || timeLeft > 20) return CommaDifficulty.medium;
    return CommaDifficulty.hard;
  }
}
