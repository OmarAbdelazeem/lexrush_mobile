import 'package:flutter/foundation.dart';

class ScoringService {
  const ScoringService();

  int calculateAccuracy({
    required int correctAnswers,
    required int wrongAnswers,
    required int missedAnswers,
  }) {
    final int total = correctAnswers + wrongAnswers + missedAnswers;
    if (total == 0) return 0;
    final int accuracy = ((correctAnswers / total) * 100).round();
    debugPrint(
      '[ScoringService] accuracy correct=$correctAnswers wrong=$wrongAnswers missed=$missedAnswers value=$accuracy',
    );
    return accuracy;
  }

  int calculateXp({
    required int wordsSolved,
    required int bestCombo,
    required int accuracy,
  }) {
    final int xp =
        (wordsSolved * 10) + (bestCombo * 5) + (accuracy >= 90 ? 50 : 0) + (bestCombo >= 10 ? 25 : 0);
    debugPrint(
      '[ScoringService] xp words=$wordsSolved bestCombo=$bestCombo accuracy=$accuracy value=$xp',
    );
    return xp;
  }
}
