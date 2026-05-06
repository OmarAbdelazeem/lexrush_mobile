import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_difficulty.dart';

class SequencingDifficultyService {
  const SequencingDifficultyService();

  SequencingDifficulty difficultyFor({required int nextRoundId}) {
    if (nextRoundId <= 3) {
      return SequencingDifficulty.beginner;
    }
    return SequencingDifficulty.medium;
  }
}
