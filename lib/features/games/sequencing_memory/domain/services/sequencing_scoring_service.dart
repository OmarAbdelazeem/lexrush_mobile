class SequencingScoringService {
  const SequencingScoringService();

  static const int perfectPartPoints = 100;
  static const int perfectCombinedPoints = 200;
  static const int partialPositionPoints = 20;

  int correctPositions({
    required List<String> correctOrder,
    required List<String> userOrder,
  }) {
    int count = 0;
    for (int i = 0; i < correctOrder.length && i < userOrder.length; i += 1) {
      if (correctOrder[i] == userOrder[i]) {
        count += 1;
      }
    }
    return count;
  }

  int pointsFor({
    required int correctPositions,
    required int totalPositions,
    required bool combined,
  }) {
    if (correctPositions == totalPositions) {
      return combined ? perfectCombinedPoints : perfectPartPoints;
    }
    return correctPositions * partialPositionPoints;
  }

  int accuracy({
    required int totalCorrectPositions,
    required int totalPositions,
  }) {
    if (totalPositions == 0) {
      return 0;
    }
    return ((totalCorrectPositions / totalPositions) * 100).round();
  }
}
