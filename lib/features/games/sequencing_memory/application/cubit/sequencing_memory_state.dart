import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_game_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_round.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_round_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_stage.dart';

class SequencingMemoryState extends Equatable {
  const SequencingMemoryState({
    required this.stage,
    required this.score,
    required this.currentChallengeIndex,
    required this.totalChallenges,
    required this.spokenProgress,
    required this.currentItems,
    required this.currentCards,
    required this.replayedStageKeys,
    required this.replayCount,
    required this.stageReplayCount,
    required this.totalAttempts,
    required this.totalCorrectPositions,
    required this.totalPositions,
    required this.perfectStages,
    required this.longestSequenceRemembered,
    required this.responseTimesMs,
    required this.review,
    this.currentRound,
    this.pausedFromStage,
    this.lastResult,
    this.result,
  });

  factory SequencingMemoryState.initial() {
    return const SequencingMemoryState(
      stage: SequencingStage.initial,
      score: 0,
      currentChallengeIndex: 0,
      totalChallenges: 3,
      spokenProgress: 0,
      currentItems: <String>[],
      currentCards: <String>[],
      replayedStageKeys: <String>[],
      replayCount: 0,
      stageReplayCount: 0,
      totalAttempts: 0,
      totalCorrectPositions: 0,
      totalPositions: 0,
      perfectStages: 0,
      longestSequenceRemembered: 0,
      responseTimesMs: <int>[],
      review: <SequencingRoundResult>[],
    );
  }

  final SequencingStage stage;
  final int score;
  final int currentChallengeIndex;
  final int totalChallenges;
  final int spokenProgress;
  final List<String> currentItems;
  final List<String> currentCards;
  final List<String> replayedStageKeys;
  final int replayCount;
  final int stageReplayCount;
  final int totalAttempts;
  final int totalCorrectPositions;
  final int totalPositions;
  final int perfectStages;
  final int longestSequenceRemembered;
  final List<int> responseTimesMs;
  final List<SequencingRoundResult> review;
  final SequencingRound? currentRound;
  final SequencingStage? pausedFromStage;
  final SequencingRoundResult? lastResult;
  final SequencingGameResult? result;

  bool get canReplay {
    return switch (stage) {
      SequencingStage.arrangePartOne || SequencingStage.arrangePartTwo =>
        !replayedStageKeys.contains(activeStageKey),
      _ => false,
    };
  }

  String get activeStageKey {
    return '${currentRound?.roundId ?? 0}:${stage.name}';
  }

  SequencingMemoryState copyWith({
    SequencingStage? stage,
    int? score,
    int? currentChallengeIndex,
    int? totalChallenges,
    int? spokenProgress,
    List<String>? currentItems,
    List<String>? currentCards,
    List<String>? replayedStageKeys,
    int? replayCount,
    int? stageReplayCount,
    int? totalAttempts,
    int? totalCorrectPositions,
    int? totalPositions,
    int? perfectStages,
    int? longestSequenceRemembered,
    List<int>? responseTimesMs,
    List<SequencingRoundResult>? review,
    SequencingRound? currentRound,
    bool clearCurrentRound = false,
    SequencingStage? pausedFromStage,
    bool clearPausedFromStage = false,
    SequencingRoundResult? lastResult,
    bool clearLastResult = false,
    SequencingGameResult? result,
    bool clearResult = false,
  }) {
    return SequencingMemoryState(
      stage: stage ?? this.stage,
      score: score ?? this.score,
      currentChallengeIndex:
          currentChallengeIndex ?? this.currentChallengeIndex,
      totalChallenges: totalChallenges ?? this.totalChallenges,
      spokenProgress: spokenProgress ?? this.spokenProgress,
      currentItems: currentItems ?? this.currentItems,
      currentCards: currentCards ?? this.currentCards,
      replayedStageKeys: replayedStageKeys ?? this.replayedStageKeys,
      replayCount: replayCount ?? this.replayCount,
      stageReplayCount: stageReplayCount ?? this.stageReplayCount,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      totalCorrectPositions:
          totalCorrectPositions ?? this.totalCorrectPositions,
      totalPositions: totalPositions ?? this.totalPositions,
      perfectStages: perfectStages ?? this.perfectStages,
      longestSequenceRemembered:
          longestSequenceRemembered ?? this.longestSequenceRemembered,
      responseTimesMs: responseTimesMs ?? this.responseTimesMs,
      review: review ?? this.review,
      currentRound: clearCurrentRound
          ? null
          : currentRound ?? this.currentRound,
      pausedFromStage: clearPausedFromStage
          ? null
          : pausedFromStage ?? this.pausedFromStage,
      lastResult: clearLastResult ? null : lastResult ?? this.lastResult,
      result: clearResult ? null : result ?? this.result,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    stage,
    score,
    currentChallengeIndex,
    totalChallenges,
    spokenProgress,
    currentItems,
    currentCards,
    replayedStageKeys,
    replayCount,
    stageReplayCount,
    totalAttempts,
    totalCorrectPositions,
    totalPositions,
    perfectStages,
    longestSequenceRemembered,
    responseTimesMs,
    review,
    currentRound,
    pausedFromStage,
    lastResult,
    result,
  ];
}
