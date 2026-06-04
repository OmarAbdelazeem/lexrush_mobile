import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_prompt.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_round_result.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_token.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';

enum CommasStatus {
  initial,
  playing,
  correctFeedback,
  wrongFeedback,
  sentenceComplete,
  paused,
  completed,
}

class CommasState extends Equatable {
  const CommasState({
    required this.status,
    required this.timeLeft,
    required this.score,
    required this.bestCombo,
    required this.combo,
    required this.totalAttempts,
    required this.correctTaps,
    required this.wrongTaps,
    required this.sentencesCompleted,
    required this.currentPrompt,
    required this.tokens,
    required this.placedCommaIndexes,
    required this.wrongGapIndexes,
    required this.remainingCommaCount,
    required this.feedbackText,
    required this.promptExplanation,
    required this.flashGapAfterTokenIndex,
    required this.promptCompleted,
    required this.review,
    required this.result,
  });

  factory CommasState.initial() {
    return const CommasState(
      status: CommasStatus.initial,
      timeLeft: 60,
      score: 0,
      bestCombo: 0,
      combo: 0,
      totalAttempts: 0,
      correctTaps: 0,
      wrongTaps: 0,
      sentencesCompleted: 0,
      currentPrompt: null,
      tokens: <CommaToken>[],
      placedCommaIndexes: <int>{},
      wrongGapIndexes: <int>[],
      remainingCommaCount: 0,
      feedbackText: null,
      promptExplanation: null,
      flashGapAfterTokenIndex: null,
      promptCompleted: false,
      review: <CommaRoundResult>[],
      result: null,
    );
  }

  final CommasStatus status;
  final int timeLeft;
  final int score;
  final int bestCombo;
  final int combo;
  final int totalAttempts;
  final int correctTaps;
  final int wrongTaps;
  final int sentencesCompleted;
  final CommaPrompt? currentPrompt;
  final List<CommaToken> tokens;
  final Set<int> placedCommaIndexes;
  final List<int> wrongGapIndexes;
  final int remainingCommaCount;
  final String? feedbackText;
  final String? promptExplanation;
  final int? flashGapAfterTokenIndex;
  final bool promptCompleted;
  final List<CommaRoundResult> review;
  final CommasGameResult? result;

  CommasState copyWith({
    CommasStatus? status,
    int? timeLeft,
    int? score,
    int? bestCombo,
    int? combo,
    int? totalAttempts,
    int? correctTaps,
    int? wrongTaps,
    int? sentencesCompleted,
    CommaPrompt? currentPrompt,
    bool clearCurrentPrompt = false,
    List<CommaToken>? tokens,
    Set<int>? placedCommaIndexes,
    List<int>? wrongGapIndexes,
    int? remainingCommaCount,
    String? feedbackText,
    bool clearFeedbackText = false,
    String? promptExplanation,
    bool clearPromptExplanation = false,
    int? flashGapAfterTokenIndex,
    bool clearFlashGap = false,
    bool? promptCompleted,
    List<CommaRoundResult>? review,
    CommasGameResult? result,
  }) {
    return CommasState(
      status: status ?? this.status,
      timeLeft: timeLeft ?? this.timeLeft,
      score: score ?? this.score,
      bestCombo: bestCombo ?? this.bestCombo,
      combo: combo ?? this.combo,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      correctTaps: correctTaps ?? this.correctTaps,
      wrongTaps: wrongTaps ?? this.wrongTaps,
      sentencesCompleted: sentencesCompleted ?? this.sentencesCompleted,
      currentPrompt: clearCurrentPrompt
          ? null
          : currentPrompt ?? this.currentPrompt,
      tokens: tokens ?? this.tokens,
      placedCommaIndexes: placedCommaIndexes ?? this.placedCommaIndexes,
      wrongGapIndexes: wrongGapIndexes ?? this.wrongGapIndexes,
      remainingCommaCount: remainingCommaCount ?? this.remainingCommaCount,
      feedbackText: clearFeedbackText
          ? null
          : feedbackText ?? this.feedbackText,
      promptExplanation: clearPromptExplanation
          ? null
          : promptExplanation ?? this.promptExplanation,
      flashGapAfterTokenIndex: clearFlashGap
          ? null
          : flashGapAfterTokenIndex ?? this.flashGapAfterTokenIndex,
      promptCompleted: promptCompleted ?? this.promptCompleted,
      review: review ?? this.review,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    timeLeft,
    score,
    bestCombo,
    combo,
    totalAttempts,
    correctTaps,
    wrongTaps,
    sentencesCompleted,
    currentPrompt,
    tokens,
    placedCommaIndexes,
    wrongGapIndexes,
    remainingCommaCount,
    feedbackText,
    promptExplanation,
    flashGapAfterTokenIndex,
    promptCompleted,
    review,
    result,
  ];
}
