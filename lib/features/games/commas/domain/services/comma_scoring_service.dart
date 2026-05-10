class CommaScoringService {
  const CommaScoringService();

  static const int correctCommaPoints = 100;
  static const int promptCompleteBonus = 100;
  static const int wrongTapPenaltySeconds = 3;

  int accuracy({required int correctTaps, required int wrongTaps}) {
    final int total = correctTaps + wrongTaps;
    if (total == 0) return 0;
    return ((correctTaps / total) * 100).round();
  }
}
