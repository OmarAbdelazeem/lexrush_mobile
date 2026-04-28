import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_round.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';

enum AntonymRushStatus {
  idle,
  playing,
  paused,
  roundFeedback,
  ended,
}

enum RoundOutcome {
  correct,
  wrong,
  missed,
}

enum MissedReason {
  correctEscaped,
  allEscaped,
  watchdog,
  roundTimeout,
}

class AntonymRushState extends Equatable {
  const AntonymRushState({
    required this.status,
    required this.timeLeft,
    required this.score,
    required this.combo,
    required this.bestCombo,
    required this.totalAttempts,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.missedWords,
    required this.wordsSolved,
    required this.currentSpeed,
    required this.currentRound,
    required this.gameResult,
    required this.lastOutcome,
    required this.escapedOptionIds,
    required this.feedbackText,
  });

  factory AntonymRushState.initial() {
    return const AntonymRushState(
      status: AntonymRushStatus.idle,
      timeLeft: 60,
      score: 0,
      combo: 0,
      bestCombo: 0,
      totalAttempts: 0,
      correctAnswers: 0,
      wrongAnswers: 0,
      missedWords: 0,
      wordsSolved: 0,
      currentSpeed: 4.9,
      currentRound: null,
      gameResult: null,
      lastOutcome: null,
      escapedOptionIds: <String>{},
      feedbackText: null,
    );
  }

  final AntonymRushStatus status;
  final int timeLeft;
  final int score;
  final int combo;
  final int bestCombo;
  final int totalAttempts;
  final int correctAnswers;
  final int wrongAnswers;
  final int missedWords;
  final int wordsSolved;
  final double currentSpeed;
  final AntonymRound? currentRound;
  final GameResult? gameResult;
  final RoundOutcome? lastOutcome;
  final Set<String> escapedOptionIds;
  final String? feedbackText;

  AntonymRushState copyWith({
    AntonymRushStatus? status,
    int? timeLeft,
    int? score,
    int? combo,
    int? bestCombo,
    int? totalAttempts,
    int? correctAnswers,
    int? wrongAnswers,
    int? missedWords,
    int? wordsSolved,
    double? currentSpeed,
    AntonymRound? currentRound,
    bool clearRound = false,
    GameResult? gameResult,
    RoundOutcome? lastOutcome,
    Set<String>? escapedOptionIds,
    String? feedbackText,
    bool clearFeedback = false,
  }) {
    return AntonymRushState(
      status: status ?? this.status,
      timeLeft: timeLeft ?? this.timeLeft,
      score: score ?? this.score,
      combo: combo ?? this.combo,
      bestCombo: bestCombo ?? this.bestCombo,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      missedWords: missedWords ?? this.missedWords,
      wordsSolved: wordsSolved ?? this.wordsSolved,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentRound: clearRound ? null : (currentRound ?? this.currentRound),
      gameResult: gameResult ?? this.gameResult,
      lastOutcome: lastOutcome ?? this.lastOutcome,
      escapedOptionIds: escapedOptionIds ?? this.escapedOptionIds,
      feedbackText: clearFeedback ? null : (feedbackText ?? this.feedbackText),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        timeLeft,
        score,
        combo,
        bestCombo,
        totalAttempts,
        correctAnswers,
        wrongAnswers,
        missedWords,
        wordsSolved,
        currentSpeed,
        currentRound,
        gameResult,
        lastOutcome,
        escapedOptionIds,
        feedbackText,
      ];
}
