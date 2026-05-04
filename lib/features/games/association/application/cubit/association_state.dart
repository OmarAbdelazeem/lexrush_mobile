import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/association/domain/entities/association_game_result.dart';
import 'package:lexrush/features/games/association/domain/entities/association_outcome.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round_result.dart';

enum AssociationStatus { initial, playing, feedback, paused, finished }

class AssociationState extends Equatable {
  const AssociationState({
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
    required this.responseTimesMs,
    required this.review,
    this.currentRound,
    this.selectedOptionId,
    this.lastOutcome,
    this.result,
  });

  factory AssociationState.initial() {
    return const AssociationState(
      status: AssociationStatus.initial,
      timeLeft: 60,
      score: 0,
      combo: 0,
      bestCombo: 0,
      totalAttempts: 0,
      correctAnswers: 0,
      wrongAnswers: 0,
      missedWords: 0,
      wordsSolved: 0,
      responseTimesMs: <int>[],
      review: <AssociationRoundResult>[],
    );
  }

  final AssociationStatus status;
  final int timeLeft;
  final int score;
  final int combo;
  final int bestCombo;
  final int totalAttempts;
  final int correctAnswers;
  final int wrongAnswers;
  final int missedWords;
  final int wordsSolved;
  final List<int> responseTimesMs;
  final List<AssociationRoundResult> review;
  final AssociationRound? currentRound;
  final String? selectedOptionId;
  final AssociationOutcome? lastOutcome;
  final AssociationGameResult? result;

  bool get isFeedback => status == AssociationStatus.feedback;
  bool get isPaused => status == AssociationStatus.paused;
  bool get isFinished => status == AssociationStatus.finished;

  AssociationState copyWith({
    AssociationStatus? status,
    int? timeLeft,
    int? score,
    int? combo,
    int? bestCombo,
    int? totalAttempts,
    int? correctAnswers,
    int? wrongAnswers,
    int? missedWords,
    int? wordsSolved,
    List<int>? responseTimesMs,
    List<AssociationRoundResult>? review,
    AssociationRound? currentRound,
    bool clearRound = false,
    String? selectedOptionId,
    bool clearSelectedOption = false,
    AssociationOutcome? lastOutcome,
    bool clearLastOutcome = false,
    AssociationGameResult? result,
    bool clearResult = false,
  }) {
    return AssociationState(
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
      responseTimesMs: responseTimesMs ?? this.responseTimesMs,
      review: review ?? this.review,
      currentRound: clearRound ? null : currentRound ?? this.currentRound,
      selectedOptionId: clearSelectedOption
          ? null
          : selectedOptionId ?? this.selectedOptionId,
      lastOutcome: clearLastOutcome ? null : lastOutcome ?? this.lastOutcome,
      result: clearResult ? null : result ?? this.result,
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
    responseTimesMs,
    review,
    currentRound,
    selectedOptionId,
    lastOutcome,
    result,
  ];
}
