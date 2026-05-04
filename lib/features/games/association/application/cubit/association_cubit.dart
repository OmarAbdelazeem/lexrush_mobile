import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexrush/features/games/association/application/cubit/association_state.dart';
import 'package:lexrush/features/games/association/data/association_prompts.dart';
import 'package:lexrush/features/games/association/domain/entities/association_game_result.dart';
import 'package:lexrush/features/games/association/domain/entities/association_option.dart';
import 'package:lexrush/features/games/association/domain/entities/association_outcome.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round_result.dart';
import 'package:lexrush/features/games/association/domain/services/association_round_generator.dart';
import 'package:lexrush/shared/application/cubits/base_game_session_cubit.dart';
import 'package:lexrush/shared/application/services/replay_goal_service.dart';
import 'package:lexrush/shared/application/services/scoring_service.dart';
import 'package:lexrush/shared/domain/contracts/lexrush_game_controller.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';

class AssociationCubit extends BaseGameSessionCubit<AssociationState>
    implements LexRushGameController {
  AssociationCubit({
    AssociationRoundGenerator? roundGenerator,
    ScoringService? scoringService,
    ReplayGoalService? replayGoalService,
  }) : _roundGenerator =
           roundGenerator ??
           AssociationRoundGenerator(prompts: associationPrompts),
       _scoringService = scoringService ?? const ScoringService(),
       _replayGoalService = replayGoalService ?? const ReplayGoalService(),
       super(AssociationState.initial());

  final AssociationRoundGenerator _roundGenerator;
  final ScoringService _scoringService;
  final ReplayGoalService _replayGoalService;
  final Set<int> _resolvedRoundIds = <int>{};

  Timer? _roundTimer;
  Timer? _transitionTimer;
  DateTime? _roundDeadline;
  DateTime? _transitionDeadline;
  Duration? _pausedRoundRemaining;
  Duration? _pausedTransitionRemaining;
  AssociationStatus? _pausedFromStatus;
  bool _ended = false;

  static const int _sessionSeconds = 60;
  static const int _correctPoints = 100;
  static const int _wrongPenaltySeconds = 3;
  static const int _missedPenaltySeconds = 2;
  static const Duration _correctDelay = Duration(milliseconds: 350);
  static const Duration _feedbackDelay = Duration(milliseconds: 1800);

  AssociationGameResult? get gameResult => state.result;

  @override
  void start() {
    _logTelemetry('session_start');
    _ended = false;
    _cancelRoundTimer();
    _cancelTransitionTimer();
    _resolvedRoundIds.clear();
    _roundGenerator.reset();
    _pausedRoundRemaining = null;
    _pausedTransitionRemaining = null;
    _pausedFromStatus = null;
    emit(
      AssociationState.initial().copyWith(status: AssociationStatus.playing),
    );
    timerManager.start(
      durationSeconds: _sessionSeconds,
      onTick: (int secondsLeft) {
        if (!_ended) {
          emit(state.copyWith(timeLeft: secondsLeft));
        }
      },
      onFinished: endGame,
    );
    _startRound();
  }

  @override
  void pause() {
    if (state.status == AssociationStatus.paused ||
        state.status == AssociationStatus.finished ||
        _ended) {
      return;
    }
    _pausedFromStatus = state.status;
    _pausedRoundRemaining = _remainingUntil(_roundDeadline);
    _pausedTransitionRemaining = _remainingUntil(_transitionDeadline);
    _logTelemetry(
      'pause from=${state.status.name} roundRemainingMs=${_pausedRoundRemaining?.inMilliseconds ?? -1} transitionRemainingMs=${_pausedTransitionRemaining?.inMilliseconds ?? -1}',
    );
    _cancelRoundTimer();
    _cancelTransitionTimer();
    timerManager.pause();
    emit(state.copyWith(status: AssociationStatus.paused));
  }

  @override
  void resume() {
    if (state.status != AssociationStatus.paused || _ended) {
      return;
    }
    final AssociationStatus nextStatus =
        _pausedFromStatus ?? AssociationStatus.playing;
    _logTelemetry(
      'resume to=${nextStatus.name} roundRemainingMs=${_pausedRoundRemaining?.inMilliseconds ?? -1} transitionRemainingMs=${_pausedTransitionRemaining?.inMilliseconds ?? -1}',
    );
    emit(state.copyWith(status: nextStatus));
    timerManager.resume(
      onTick: (int secondsLeft) {
        if (!_ended) {
          emit(state.copyWith(timeLeft: secondsLeft));
        }
      },
      onFinished: endGame,
    );
    final AssociationRound? round = state.currentRound;
    if (nextStatus == AssociationStatus.playing &&
        round != null &&
        !round.answered) {
      _scheduleRoundMiss(round, delay: _pausedRoundRemaining);
    } else if (nextStatus == AssociationStatus.feedback) {
      _scheduleTransition(_pausedTransitionRemaining ?? _feedbackDelay);
    }
    _pausedFromStatus = null;
    _pausedRoundRemaining = null;
    _pausedTransitionRemaining = null;
  }

  @override
  void restart() {
    _logTelemetry('restart');
    start();
  }

  @override
  void submitAnswer(String answerId) {
    final AssociationRound? round = state.currentRound;
    if (!_canResolveRound(round)) {
      _logIgnoredTap(
        answerId: answerId,
        reason: 'not_resolvable',
        round: round,
      );
      return;
    }
    final AssociationOption? selected = round!.options
        .where((AssociationOption option) => option.id == answerId)
        .firstOrNull;
    if (selected == null) {
      _logIgnoredTap(
        answerId: answerId,
        reason: 'missing_option_id',
        round: round,
      );
      return;
    }
    if (selected.isCorrect) {
      _handleCorrect(round, selected);
    } else {
      _handleWrong(round, selected);
    }
  }

  void continueAfterFeedback() {
    if (state.status != AssociationStatus.feedback || _ended) {
      return;
    }
    _logTelemetry(
      'feedback_continue_manual roundId=${state.currentRound?.roundId ?? -1} outcome=${state.lastOutcome?.name ?? 'none'}',
    );
    _cancelTransitionTimer();
    _startRound();
  }

  void endGame() {
    if (_ended) {
      return;
    }
    _logTelemetry(
      'session_end score=${state.score} correct=${state.correctAnswers} wrong=${state.wrongAnswers} missed=${state.missedWords} words=${state.wordsSolved}',
    );
    _ended = true;
    _cancelRoundTimer();
    _cancelTransitionTimer();
    timerManager.cancel();
    emit(
      state.copyWith(
        status: AssociationStatus.finished,
        clearRound: true,
        result: _buildResult(),
      ),
    );
  }

  @override
  GameSessionStats? finish() {
    return state.result?.summary.stats;
  }

  void _startRound() {
    if (_ended || state.timeLeft <= 0) {
      endGame();
      return;
    }
    final AssociationRound round = _roundGenerator.generate(
      secondsLeft: state.timeLeft,
      wordsSolved: state.wordsSolved,
    );
    final Duration roundWindow = _roundGenerator.roundWindowFor(round);
    _logTelemetry(
      'round_start roundId=${round.roundId} target=${round.targetWord} hint=${round.contextHint ?? 'none'} type=${round.type.name} difficulty=${round.difficulty.name} secondsLeft=${state.timeLeft} wordsSolved=${state.wordsSolved} windowMs=${roundWindow.inMilliseconds} options=${_formatOptions(round)}',
    );
    emit(
      state.copyWith(
        status: AssociationStatus.playing,
        currentRound: round,
        clearSelectedOption: true,
        clearLastOutcome: true,
      ),
    );
    _scheduleRoundMiss(round);
  }

  void _handleCorrect(AssociationRound round, AssociationOption selected) {
    if (!_markResolved(round.roundId)) {
      return;
    }
    final int responseTime = DateTime.now()
        .difference(round.startedAt)
        .inMilliseconds;
    final int scoreBefore = state.score;
    final int comboBefore = state.combo;
    final int nextCombo = state.combo + 1;
    final AssociationRoundResult reviewEntry = _reviewEntry(
      round: round,
      selected: selected,
      outcome: AssociationOutcome.correct,
      responseTimeMs: responseTime,
    );
    _cancelRoundTimer();
    emit(
      state.copyWith(
        status: AssociationStatus.feedback,
        currentRound: round.copyWith(answered: true),
        selectedOptionId: selected.id,
        lastOutcome: AssociationOutcome.correct,
        score: state.score + _correctPoints,
        combo: nextCombo,
        bestCombo: nextCombo > state.bestCombo ? nextCombo : state.bestCombo,
        totalAttempts: state.totalAttempts + 1,
        correctAnswers: state.correctAnswers + 1,
        wordsSolved: state.wordsSolved + 1,
        responseTimesMs: <int>[...state.responseTimesMs, responseTime],
        review: <AssociationRoundResult>[...state.review, reviewEntry],
      ),
    );
    _logTelemetry(
      'tap_resolved roundId=${round.roundId} target=${round.targetWord} tappedId=${selected.id} tappedWord=${selected.word} correctWord=${round.correctAnswer} outcome=correct responseMs=$responseTime scoreBefore=$scoreBefore scoreAfter=${state.score} comboBefore=$comboBefore comboAfter=${state.combo}',
    );
    _scheduleTransition(_correctDelay);
  }

  void _handleWrong(AssociationRound round, AssociationOption selected) {
    if (!_markResolved(round.roundId)) {
      return;
    }
    final int responseTime = DateTime.now()
        .difference(round.startedAt)
        .inMilliseconds;
    final int scoreBefore = state.score;
    final int comboBefore = state.combo;
    final int timeLeftBefore = state.timeLeft;
    final int timeLeftAfter = (state.timeLeft - _wrongPenaltySeconds).clamp(
      0,
      _sessionSeconds,
    );
    timerManager.applyPenaltySeconds(_wrongPenaltySeconds);
    final AssociationRoundResult reviewEntry = _reviewEntry(
      round: round,
      selected: selected,
      outcome: AssociationOutcome.wrong,
      responseTimeMs: responseTime,
    );
    _cancelRoundTimer();
    emit(
      state.copyWith(
        status: AssociationStatus.feedback,
        currentRound: round.copyWith(answered: true),
        selectedOptionId: selected.id,
        lastOutcome: AssociationOutcome.wrong,
        timeLeft: timeLeftAfter,
        combo: 0,
        totalAttempts: state.totalAttempts + 1,
        wrongAnswers: state.wrongAnswers + 1,
        responseTimesMs: <int>[...state.responseTimesMs, responseTime],
        review: <AssociationRoundResult>[...state.review, reviewEntry],
      ),
    );
    _logTelemetry(
      'tap_resolved roundId=${round.roundId} target=${round.targetWord} tappedId=${selected.id} tappedWord=${selected.word} correctWord=${round.correctAnswer} outcome=wrong responseMs=$responseTime scoreBefore=$scoreBefore scoreAfter=${state.score} comboBefore=$comboBefore comboAfter=${state.combo} timeLeftBefore=$timeLeftBefore timeLeftAfter=${state.timeLeft}',
    );
    if (timeLeftAfter <= 0) {
      endGame();
      return;
    }
    _scheduleTransition(_feedbackDelay);
  }

  void _registerMissedRound(AssociationRound round) {
    if (!_canResolveRound(round) || !_markResolved(round.roundId)) {
      return;
    }
    final bool beginnerRound = round.roundId <= 5;
    final int timeLeftBefore = state.timeLeft;
    final int timeLeftAfter = beginnerRound
        ? state.timeLeft
        : (state.timeLeft - _missedPenaltySeconds).clamp(0, _sessionSeconds);
    if (!beginnerRound) {
      timerManager.applyPenaltySeconds(_missedPenaltySeconds);
    }
    final AssociationRoundResult reviewEntry = _reviewEntry(
      round: round,
      selected: null,
      outcome: AssociationOutcome.missed,
      responseTimeMs: null,
    );
    emit(
      state.copyWith(
        status: AssociationStatus.feedback,
        currentRound: round.copyWith(answered: true),
        clearSelectedOption: true,
        lastOutcome: AssociationOutcome.missed,
        timeLeft: timeLeftAfter,
        combo: 0,
        missedWords: state.missedWords + 1,
        review: <AssociationRoundResult>[...state.review, reviewEntry],
      ),
    );
    _logTelemetry(
      'round_missed roundId=${round.roundId} target=${round.targetWord} beginner=$beginnerRound penaltyApplied=${!beginnerRound} timeLeftBefore=$timeLeftBefore timeLeftAfter=${state.timeLeft} correctWord=${round.correctAnswer}',
    );
    if (timeLeftAfter <= 0) {
      endGame();
      return;
    }
    _scheduleTransition(_feedbackDelay);
  }

  void _scheduleRoundMiss(AssociationRound round, {Duration? delay}) {
    _cancelRoundTimer();
    final Duration roundDelay = delay ?? _roundGenerator.roundWindowFor(round);
    _roundDeadline = DateTime.now().add(roundDelay);
    _logTelemetry(
      'round_timeout_scheduled roundId=${round.roundId} delayMs=${roundDelay.inMilliseconds}',
    );
    _roundTimer = Timer(roundDelay, () {
      final AssociationRound? currentRound = state.currentRound;
      if (currentRound == null ||
          currentRound.roundId != round.roundId ||
          !_canResolveRound(currentRound)) {
        return;
      }
      _registerMissedRound(currentRound);
    });
  }

  void _scheduleTransition(Duration delay) {
    _cancelTransitionTimer();
    if (_ended || state.timeLeft <= 0) {
      endGame();
      return;
    }
    _transitionDeadline = DateTime.now().add(delay);
    _logTelemetry(
      'feedback_transition_scheduled roundId=${state.currentRound?.roundId ?? -1} outcome=${state.lastOutcome?.name ?? 'none'} delayMs=${delay.inMilliseconds}',
    );
    _transitionTimer = Timer(delay, () {
      if (_ended || state.status != AssociationStatus.feedback) {
        return;
      }
      _logTelemetry(
        'feedback_continue_auto roundId=${state.currentRound?.roundId ?? -1} outcome=${state.lastOutcome?.name ?? 'none'}',
      );
      _startRound();
    });
  }

  bool _canResolveRound(AssociationRound? round) {
    return !_ended &&
        round != null &&
        state.status == AssociationStatus.playing &&
        !round.answered &&
        !_resolvedRoundIds.contains(round.roundId);
  }

  bool _markResolved(int roundId) {
    return _resolvedRoundIds.add(roundId);
  }

  AssociationRoundResult _reviewEntry({
    required AssociationRound round,
    required AssociationOption? selected,
    required AssociationOutcome outcome,
    required int? responseTimeMs,
  }) {
    return AssociationRoundResult(
      roundId: round.roundId,
      targetWord: round.targetWord,
      correctAnswer: round.correctAnswer,
      selectedAnswer: selected?.word,
      explanation: round.explanation,
      outcome: outcome,
      responseTimeMs: responseTimeMs,
    );
  }

  AssociationGameResult _buildResult() {
    final int accuracy = _scoringService.calculateAccuracy(
      correctAnswers: state.correctAnswers,
      wrongAnswers: state.wrongAnswers,
      missedAnswers: state.missedWords,
    );
    final int averageResponseMs = state.responseTimesMs.isEmpty
        ? 0
        : (state.responseTimesMs.reduce((int a, int b) => a + b) /
                  state.responseTimesMs.length)
              .round();
    final int xp = _scoringService.calculateXp(
      wordsSolved: state.wordsSolved,
      bestCombo: state.bestCombo,
      accuracy: accuracy,
    );
    final GameSessionStats stats = GameSessionStats(
      score: state.score,
      accuracy: accuracy,
      bestCombo: state.bestCombo,
      xpEarned: xp,
      totalAttempts: state.totalAttempts,
      correctAnswers: state.correctAnswers,
      wordsSolved: state.wordsSolved,
      missedWords: state.missedWords,
      averageResponseTimeMs: averageResponseMs,
    );
    return AssociationGameResult(
      summary: GameResult(
        stats: stats,
        replayGoal: _replayGoalService.buildGoal(stats),
      ),
      review: state.review,
    );
  }

  Duration? _remainingUntil(DateTime? deadline) {
    if (deadline == null) {
      return null;
    }
    final Duration remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return Duration.zero;
    }
    return remaining;
  }

  void _cancelRoundTimer() {
    if (_roundTimer != null) {
      _logTelemetry('round_timeout_cancelled');
    }
    _roundTimer?.cancel();
    _roundTimer = null;
    _roundDeadline = null;
  }

  void _cancelTransitionTimer() {
    if (_transitionTimer != null) {
      _logTelemetry('feedback_transition_cancelled');
    }
    _transitionTimer?.cancel();
    _transitionTimer = null;
    _transitionDeadline = null;
  }

  @override
  Future<void> close() {
    _logTelemetry('close');
    _cancelRoundTimer();
    _cancelTransitionTimer();
    return super.close();
  }

  void _logIgnoredTap({
    required String answerId,
    required String reason,
    required AssociationRound? round,
  }) {
    _logTelemetry(
      'tap_ignored reason=$reason answerId=$answerId status=${state.status.name} roundId=${round?.roundId ?? -1} currentTarget=${round?.targetWord ?? 'none'} selected=${state.selectedOptionId ?? 'none'} lastOutcome=${state.lastOutcome?.name ?? 'none'} transitionActive=${_transitionTimer?.isActive ?? false} ended=$_ended',
    );
  }

  String _formatOptions(AssociationRound round) {
    return round.options
        .map(
          (AssociationOption option) =>
              '${option.id}:${option.word}:${option.isCorrect}',
        )
        .join('|');
  }

  void _logTelemetry(String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[AssociationTelemetry] $message');
  }
}
