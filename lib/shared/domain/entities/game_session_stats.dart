import 'package:equatable/equatable.dart';

class GameSessionStats extends Equatable {
  const GameSessionStats({
    required this.score,
    required this.accuracy,
    required this.bestCombo,
    required this.xpEarned,
    required this.totalAttempts,
    required this.correctAnswers,
    required this.wordsSolved,
    required this.missedWords,
    required this.averageResponseTimeMs,
  });

  final int score;
  final int accuracy;
  final int bestCombo;
  final int xpEarned;
  final int totalAttempts;
  final int correctAnswers;
  final int wordsSolved;
  final int missedWords;
  final int averageResponseTimeMs;

  @override
  List<Object> get props => <Object>[
        score,
        accuracy,
        bestCombo,
        xpEarned,
        totalAttempts,
        correctAnswers,
        wordsSolved,
        missedWords,
        averageResponseTimeMs,
      ];
}
