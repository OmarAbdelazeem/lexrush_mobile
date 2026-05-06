import 'package:flutter/foundation.dart';
import 'package:lexrush/features/games/sequencing_memory/application/cubit/sequencing_memory_state.dart';
import 'package:lexrush/features/games/sequencing_memory/data/sequencing_prompts.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_game_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_round.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_round_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_stage.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/services/sequencing_audio_service.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/services/sequencing_round_generator.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/services/sequencing_scoring_service.dart';
import 'package:lexrush/shared/application/cubits/base_game_session_cubit.dart';
import 'package:lexrush/shared/application/services/replay_goal_service.dart';
import 'package:lexrush/shared/domain/contracts/lexrush_game_controller.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';

class SequencingMemoryCubit extends BaseGameSessionCubit<SequencingMemoryState>
    implements LexRushGameController {
  SequencingMemoryCubit({
    SequencingRoundGenerator? roundGenerator,
    SequencingScoringService scoringService = const SequencingScoringService(),
    SequencingAudioService audioService = const MockSequencingAudioService(),
    ReplayGoalService replayGoalService = const ReplayGoalService(),
  }) : _roundGenerator =
           roundGenerator ??
           SequencingRoundGenerator(prompts: sequencingPrompts),
       _scoringService = scoringService,
       _audioService = audioService,
       _replayGoalService = replayGoalService,
       super(SequencingMemoryState.initial());

  static const int _totalChallenges = 3;

  final SequencingRoundGenerator _roundGenerator;
  final SequencingScoringService _scoringService;
  final SequencingAudioService _audioService;
  final ReplayGoalService _replayGoalService;

  SequencingAudioPlayback? _playback;
  DateTime? _arrangeStartedAt;
  bool _ended = false;

  SequencingGameResult? get gameResult => state.result;

  @override
  void start() {
    _log('session_start');
    _ended = false;
    _cancelPlayback();
    _roundGenerator.reset();
    _arrangeStartedAt = null;
    emit(
      SequencingMemoryState.initial().copyWith(
        totalChallenges: _totalChallenges,
      ),
    );
    _startNextChallenge();
  }

  @override
  void restart() {
    _log('restart');
    start();
  }

  @override
  void pause() {
    if (state.stage == SequencingStage.paused ||
        state.stage == SequencingStage.finished ||
        _ended) {
      return;
    }
    _log('pause from=${state.stage.name}');
    if (state.stage.isListening) {
      _playback?.pause();
    }
    emit(
      state.copyWith(
        stage: SequencingStage.paused,
        pausedFromStage: state.stage,
      ),
    );
  }

  @override
  void resume() {
    if (state.stage != SequencingStage.paused || _ended) {
      return;
    }
    final SequencingStage nextStage =
        state.pausedFromStage ?? SequencingStage.listenPartOne;
    _log('resume to=${nextStage.name}');
    emit(state.copyWith(stage: nextStage, clearPausedFromStage: true));
    if (nextStage.isListening) {
      _playback?.resume();
    }
  }

  @override
  void submitAnswer(String answerId) {
    submitCurrentOrder();
  }

  @override
  GameSessionStats? finish() {
    return state.result?.summary.stats;
  }

  void reorderCards(int oldIndex, int newIndex) {
    if (!state.stage.isArranging) {
      return;
    }
    final List<String> cards = state.currentCards.toList();
    final int targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final String moved = cards.removeAt(oldIndex);
    cards.insert(targetIndex, moved);
    emit(state.copyWith(currentCards: cards));
  }

  void submitCurrentOrder() {
    if (!state.stage.isArranging || state.currentRound == null) {
      return;
    }
    final List<String> correctOrder = _itemsForStage(state.stage);
    final List<String> userOrder = state.currentCards;
    final int correctPositions = _scoringService.correctPositions(
      correctOrder: correctOrder,
      userOrder: userOrder,
    );
    final bool perfect = correctPositions == correctOrder.length;
    final int points = _scoringService.pointsFor(
      correctPositions: correctPositions,
      totalPositions: correctOrder.length,
      combined: state.stage == SequencingStage.arrangeCombined,
    );
    final int recallTimeMs = _arrangeStartedAt == null
        ? 0
        : DateTime.now().difference(_arrangeStartedAt!).inMilliseconds;
    final SequencingStage feedbackStage = _feedbackStageFor(state.stage);
    final SequencingRoundResult result = SequencingRoundResult(
      roundId: state.currentRound!.roundId,
      stage: state.stage,
      correctOrder: correctOrder,
      userOrder: userOrder,
      correctPositions: correctPositions,
      pointsEarned: points,
      perfect: perfect,
      recallTimeMs: recallTimeMs,
      replayCount: state.stageReplayCount,
    );
    final int nextLongest =
        perfect && correctOrder.length > state.longestSequenceRemembered
        ? correctOrder.length
        : state.longestSequenceRemembered;

    _log(
      'submit stage=${state.stage.name} round=${state.currentRound!.roundId} correct=$correctPositions/${correctOrder.length} points=$points replay=${state.stageReplayCount}',
    );
    emit(
      state.copyWith(
        stage: feedbackStage,
        score: state.score + points,
        totalAttempts: state.totalAttempts + 1,
        totalCorrectPositions: state.totalCorrectPositions + correctPositions,
        totalPositions: state.totalPositions + correctOrder.length,
        perfectStages: perfect ? state.perfectStages + 1 : state.perfectStages,
        longestSequenceRemembered: nextLongest,
        responseTimesMs: <int>[...state.responseTimesMs, recallTimeMs],
        review: <SequencingRoundResult>[...state.review, result],
        lastResult: result,
      ),
    );
  }

  void replayCurrentPart() {
    if (!state.canReplay || state.currentRound == null) {
      return;
    }
    final SequencingStage listenStage = switch (state.stage) {
      SequencingStage.arrangePartOne => SequencingStage.listenPartOne,
      SequencingStage.arrangePartTwo => SequencingStage.listenPartTwo,
      _ => state.stage,
    };
    final String stageKey = state.activeStageKey;
    _log(
      'replay stage=${state.stage.name} round=${state.currentRound!.roundId}',
    );
    emit(
      state.copyWith(
        replayedStageKeys: <String>[...state.replayedStageKeys, stageKey],
        replayCount: state.replayCount + 1,
        stageReplayCount: state.stageReplayCount + 1,
      ),
    );
    _enterListening(listenStage);
  }

  void continueAfterFeedback() {
    if (!state.stage.isFeedback || _ended) {
      return;
    }
    switch (state.stage) {
      case SequencingStage.feedbackPartOne:
        emit(state.copyWith(stageReplayCount: 0));
        _enterListening(SequencingStage.listenPartTwo);
      case SequencingStage.feedbackPartTwo:
        _enterCombinedArrange();
      case SequencingStage.feedbackCombined:
        if (state.currentChallengeIndex >= _totalChallenges) {
          endGame();
        } else {
          _startNextChallenge();
        }
      case SequencingStage.initial:
      case SequencingStage.listenPartOne:
      case SequencingStage.arrangePartOne:
      case SequencingStage.listenPartTwo:
      case SequencingStage.arrangePartTwo:
      case SequencingStage.arrangeCombined:
      case SequencingStage.paused:
      case SequencingStage.finished:
        break;
    }
  }

  void endGame() {
    if (_ended) {
      return;
    }
    _ended = true;
    _cancelPlayback();
    _log('session_end score=${state.score} review=${state.review.length}');
    emit(
      state.copyWith(
        stage: SequencingStage.finished,
        clearCurrentRound: true,
        result: _buildResult(),
      ),
    );
  }

  void _startNextChallenge() {
    if (_ended) {
      return;
    }
    if (state.currentChallengeIndex >= _totalChallenges) {
      endGame();
      return;
    }
    final SequencingRound round = _roundGenerator.generate();
    emit(
      state.copyWith(
        currentChallengeIndex: state.currentChallengeIndex + 1,
        currentRound: round,
        currentItems: round.partOne,
        currentCards: const <String>[],
        spokenProgress: 0,
        stageReplayCount: 0,
        clearLastResult: true,
      ),
    );
    _enterListening(SequencingStage.listenPartOne);
  }

  void _enterListening(SequencingStage stage) {
    if (_ended || state.currentRound == null) {
      return;
    }
    final List<String> items = _itemsForStage(stage);
    _cancelPlayback();
    emit(
      state.copyWith(
        stage: stage,
        currentItems: items,
        currentCards: const <String>[],
        spokenProgress: 0,
        clearLastResult: true,
      ),
    );
    _playback = _audioService.playSequence(
      items: items,
      onProgress: (int spokenCount) {
        if (!_ended && state.stage == stage) {
          emit(state.copyWith(spokenProgress: spokenCount));
        }
      },
      onComplete: () {
        if (!_ended && state.stage == stage) {
          _enterArrange(_arrangeStageFor(stage));
        }
      },
    );
  }

  void _enterArrange(SequencingStage stage) {
    if (_ended || state.currentRound == null) {
      return;
    }
    final List<String> items = _itemsForStage(stage);
    final int salt = switch (stage) {
      SequencingStage.arrangePartOne => 11,
      SequencingStage.arrangePartTwo => 17,
      SequencingStage.arrangeCombined => 23,
      _ => 0,
    };
    _arrangeStartedAt = DateTime.now();
    emit(
      state.copyWith(
        stage: stage,
        currentItems: items,
        currentCards: _roundGenerator.shuffledCards(
          items: items,
          roundId: state.currentRound!.roundId,
          salt: salt,
        ),
        spokenProgress: items.length,
      ),
    );
  }

  void _enterCombinedArrange() {
    emit(state.copyWith(stageReplayCount: 0));
    _enterArrange(SequencingStage.arrangeCombined);
  }

  List<String> _itemsForStage(SequencingStage stage) {
    final SequencingRound? round = state.currentRound;
    if (round == null) {
      return const <String>[];
    }
    return switch (stage) {
      SequencingStage.listenPartOne ||
      SequencingStage.arrangePartOne ||
      SequencingStage.feedbackPartOne => round.partOne,
      SequencingStage.listenPartTwo ||
      SequencingStage.arrangePartTwo ||
      SequencingStage.feedbackPartTwo => round.partTwo,
      SequencingStage.arrangeCombined ||
      SequencingStage.feedbackCombined => round.combined,
      _ => const <String>[],
    };
  }

  SequencingStage _arrangeStageFor(SequencingStage stage) {
    return switch (stage) {
      SequencingStage.listenPartOne => SequencingStage.arrangePartOne,
      SequencingStage.listenPartTwo => SequencingStage.arrangePartTwo,
      _ => SequencingStage.arrangePartOne,
    };
  }

  SequencingStage _feedbackStageFor(SequencingStage stage) {
    return switch (stage) {
      SequencingStage.arrangePartOne => SequencingStage.feedbackPartOne,
      SequencingStage.arrangePartTwo => SequencingStage.feedbackPartTwo,
      SequencingStage.arrangeCombined => SequencingStage.feedbackCombined,
      _ => SequencingStage.feedbackPartOne,
    };
  }

  SequencingGameResult _buildResult() {
    final int accuracy = _scoringService.accuracy(
      totalCorrectPositions: state.totalCorrectPositions,
      totalPositions: state.totalPositions,
    );
    final int averageRecallTimeMs = state.responseTimesMs.isEmpty
        ? 0
        : (state.responseTimesMs.reduce((int a, int b) => a + b) /
                  state.responseTimesMs.length)
              .round();
    final GameSessionStats stats = GameSessionStats(
      score: state.score,
      accuracy: accuracy,
      bestCombo: state.perfectStages,
      xpEarned:
          (state.perfectStages * 20) +
          (state.longestSequenceRemembered * 5) +
          (accuracy >= 90 ? 50 : 0),
      totalAttempts: state.totalAttempts,
      correctAnswers: state.perfectStages,
      wordsSolved: state.perfectStages,
      missedWords: state.totalAttempts - state.perfectStages,
      averageResponseTimeMs: averageRecallTimeMs,
    );
    return SequencingGameResult(
      summary: GameResult(
        stats: stats,
        replayGoal: _replayGoalService.buildGoal(stats),
      ),
      review: state.review,
      sequencesCompleted: state.currentChallengeIndex,
      perfectStages: state.perfectStages,
      longestSequenceRemembered: state.longestSequenceRemembered,
      replayCount: state.replayCount,
      averageRecallTimeMs: averageRecallTimeMs,
    );
  }

  void _cancelPlayback() {
    _playback?.cancel();
    _playback = null;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[SequencingMemoryTelemetry] $message');
    }
  }

  @override
  Future<void> close() {
    _cancelPlayback();
    return super.close();
  }
}
