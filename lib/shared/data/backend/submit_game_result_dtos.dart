class SubmitGameResultRequest {
  const SubmitGameResultRequest({
    required this.score,
    required this.accuracy,
    required this.totalAttempts,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.missedAnswers,
    required this.wordsSolved,
    required this.bestCombo,
    required this.averageResponseTimeMs,
  });

  factory SubmitGameResultRequest.fromJson(Map<String, dynamic> json) {
    return SubmitGameResultRequest(
      score: json['score'] as int,
      accuracy: (json['accuracy'] as num).toDouble(),
      totalAttempts: json['totalAttempts'] as int,
      correctAnswers: json['correctAnswers'] as int,
      wrongAnswers: json['wrongAnswers'] as int,
      missedAnswers: json['missedAnswers'] as int,
      wordsSolved: json['wordsSolved'] as int,
      bestCombo: json['bestCombo'] as int,
      averageResponseTimeMs: json['averageResponseTimeMs'] as int,
    );
  }

  final int score;
  final double accuracy;
  final int totalAttempts;
  final int correctAnswers;
  final int wrongAnswers;
  final int missedAnswers;
  final int wordsSolved;
  final int bestCombo;
  final int averageResponseTimeMs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'score': score,
      'accuracy': accuracy,
      'totalAttempts': totalAttempts,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'missedAnswers': missedAnswers,
      'wordsSolved': wordsSolved,
      'bestCombo': bestCombo,
      'averageResponseTimeMs': averageResponseTimeMs,
    };
  }
}

class SubmitGameResultResponse {
  const SubmitGameResultResponse({
    required this.resultId,
    required this.sessionId,
    required this.gameId,
    required this.score,
    required this.accuracy,
    required this.xpEarned,
    required this.totalAttempts,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.missedAnswers,
    required this.createdAt,
  });

  factory SubmitGameResultResponse.fromJson(Map<String, dynamic> json) {
    return SubmitGameResultResponse(
      resultId: json['resultId'] as String,
      sessionId: json['sessionId'] as String,
      gameId: json['gameId'] as String,
      score: json['score'] as int,
      accuracy: (json['accuracy'] as num).toDouble(),
      xpEarned: json['xpEarned'] as int,
      totalAttempts: json['totalAttempts'] as int,
      correctAnswers: json['correctAnswers'] as int,
      wrongAnswers: json['wrongAnswers'] as int,
      missedAnswers: json['missedAnswers'] as int,
      createdAt: json['createdAt'] as String,
    );
  }

  final String resultId;
  final String sessionId;
  final String gameId;
  final int score;
  final double accuracy;
  final int xpEarned;
  final int totalAttempts;
  final int correctAnswers;
  final int wrongAnswers;
  final int missedAnswers;
  final String createdAt;
}
