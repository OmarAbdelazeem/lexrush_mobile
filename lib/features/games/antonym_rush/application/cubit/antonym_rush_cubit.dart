import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_state.dart';
import 'package:lexrush/features/games/antonym_rush/data/antonym_pairs.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_round.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/balloon_option.dart';
import 'package:lexrush/features/games/antonym_rush/domain/services/antonym_difficulty_service.dart';
import 'package:lexrush/features/games/antonym_rush/domain/services/antonym_round_generator.dart';
import 'package:lexrush/shared/application/cubits/base_game_session_cubit.dart';
import 'package:lexrush/shared/application/services/replay_goal_service.dart';
import 'package:lexrush/shared/application/services/scoring_service.dart';
import 'package:lexrush/shared/domain/contracts/lexrush_game_controller.dart';
import 'package:lexrush/shared/domain/entities/difficulty_phase.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';

class AntonymRushCubit extends BaseGameSessionCubit<AntonymRushState>
    implements LexRushGameController {
  AntonymRushCubit({
    AntonymRoundGenerator? roundGenerator,
    AntonymDifficultyService? difficultyService,
    ScoringService? scoringService,
    ReplayGoalService? replayGoalService,
  }) : _difficultyService =
           difficultyService ?? const AntonymDifficultyService(),
       _scoringService = scoringService ?? const ScoringService(),
       _replayGoalService = replayGoalService ?? const ReplayGoalService(),
       _roundGenerator =
           roundGenerator ??
           AntonymRoundGenerator(
             pairs: antonymPairs,
             difficultyService:
                 difficultyService ?? const AntonymDifficultyService(),
           ),
       super(AntonymRushState.initial());

  final AntonymDifficultyService _difficultyService;
  final ScoringService _scoringService;
  final ReplayGoalService _replayGoalService;
  final AntonymRoundGenerator _roundGenerator;
  final List<int> _responseTimesMs = <int>[];
  final Set<int> _resolvedRoundIds = <int>{};
  final Map<int, _RoundTelemetry> _roundTelemetry = <int, _RoundTelemetry>{};
  final Map<MissedReason, int> _missedReasonCounts = <MissedReason, int>{
    MissedReason.correctEscaped: 0,
    MissedReason.allEscaped: 0,
    MissedReason.watchdog: 0,
    MissedReason.roundTimeout: 0,
  };
  Timer? _nextRoundTimer;
  Timer? _roundEscapeTimer;
  bool _ended = false;
  bool _pendingRoundStartOnResume = false;

  static const int _correctPoints = 100;
  static const int _wrongPenaltySeconds = 3;
  static const int _missedPenaltySeconds = 2;
  static const Duration _correctDelay = Duration(milliseconds: 300);
  static const Duration _wrongDelay = Duration(milliseconds: 550);
  static const Duration _missedDelay = Duration(milliseconds: 100);
  static const int _beginnerRoundCount = 5;
  static const int _beginnerMinAutoMissMs = 5000;
  static const int _earlyMinAutoMissMs = 4200;
  static const int _midMinAutoMissMs = 3400;
  static const int _lateMinAutoMissMs = 2600;
  static const int _escapeSafetyBufferMs = 2000;

  @override
  void start() {
    debugPrint('[AntonymRushCubit] start');
    _ended = false;
    _responseTimesMs.clear();
    _resolvedRoundIds.clear();
    _roundTelemetry.clear();
    _resetMissedReasonCounts();
    _roundGenerator.reset();
    _nextRoundTimer?.cancel();
    _roundEscapeTimer?.cancel();
    _pendingRoundStartOnResume = false;
    final phase = _difficultyService.phaseForTimeLeft(60);
    final speed = _difficultyService.speedFor(
      phase: phase,
      wordsSolved: 0,
      beginnerMode: true,
    );
    emit(
      AntonymRushState.initial().copyWith(
        status: AntonymRushStatus.playing,
        currentSpeed: speed,
      ),
    );
    timerManager.start(
      durationSeconds: 60,
      onTick: (int secondsLeft) {
        emit(state.copyWith(timeLeft: secondsLeft));
      },
      onFinished: endGame,
    );
    _startRound();
  }

  @override
  void pause() {
    if (state.status == AntonymRushStatus.paused || _ended) return;
    debugPrint('[AntonymRushCubit] pause');
    timerManager.pause();
    if (_nextRoundTimer != null) {
      _pendingRoundStartOnResume = true;
    }
    _nextRoundTimer?.cancel();
    _roundEscapeTimer?.cancel();
    emit(state.copyWith(status: AntonymRushStatus.paused));
  }

  @override
  void resume() {
    if (state.status != AntonymRushStatus.paused || _ended) return;
    debugPrint('[AntonymRushCubit] resume');
    emit(state.copyWith(status: AntonymRushStatus.playing));
    timerManager.resume(
      onTick: (int secondsLeft) => emit(state.copyWith(timeLeft: secondsLeft)),
      onFinished: endGame,
    );
    if (_pendingRoundStartOnResume) {
      debugPrint('[AntonymRushCubit] resume -> pending round start');
      _pendingRoundStartOnResume = false;
      _startRound();
      return;
    }
    final AntonymRound? currentRound = state.currentRound;
    if (currentRound != null && !currentRound.answered) {
      _scheduleRoundEscape(currentRound);
    }
  }

  @override
  void restart() {
    debugPrint('[AntonymRushCubit] restart');
    start();
  }

  @override
  void submitAnswer(String answerId) {
    final AntonymRound? round = state.currentRound;
    if (round == null) {
      _emitIgnoredTapTelemetry(
        round: null,
        answerId: answerId,
        reason: 'no_current_round',
      );
      return;
    }
    if (state.status != AntonymRushStatus.playing) {
      _emitIgnoredTapTelemetry(
        round: round,
        answerId: answerId,
        reason: 'not_playing',
      );
      return;
    }
    if (!_canResolveRound(round)) {
      _emitIgnoredTapTelemetry(
        round: round,
        answerId: answerId,
        reason: 'round_locked_or_resolved',
      );
      return;
    }
    final AntonymRound activeRound = round;
    final BalloonOption? selected = _optionForId(activeRound, answerId);
    if (selected == null) {
      _emitIgnoredTapTelemetry(
        round: activeRound,
        answerId: answerId,
        reason: 'missing_option_id',
      );
      return;
    }
    final int scoreBefore = state.score;
    final int comboBefore = state.combo;
    final RoundOutcome expectedOutcome = selected.isCorrect
        ? RoundOutcome.correct
        : RoundOutcome.wrong;
    if (selected.isCorrect) {
      _handleCorrect(activeRound);
    } else {
      _handleWrong(activeRound);
    }
    _emitTapTelemetry(
      round: activeRound,
      selected: selected,
      expectedOutcome: expectedOutcome,
      scoreBefore: scoreBefore,
      scoreAfter: state.score,
      comboBefore: comboBefore,
      comboAfter: state.combo,
    );
  }

  void registerMissedRound({MissedReason reason = MissedReason.roundTimeout}) {
    final AntonymRound? round = state.currentRound;
    if (!_canResolveRound(round)) return;
    final int roundId = round!.roundId;
    if (!_markResolved(roundId)) return;
    final int timeLeftBefore = state.timeLeft;
    final bool applyPenalty = round.roundId > 5;
    final int timeLeftAfter = applyPenalty
        ? (timeLeftBefore - _missedPenaltySeconds).clamp(0, 60)
        : timeLeftBefore;
    _missedReasonCounts[reason] = (_missedReasonCounts[reason] ?? 0) + 1;
    _roundEscapeTimer?.cancel();
    _emitTelemetry(
      round: round,
      event: 'round_resolved',
      outcome: RoundOutcome.missed,
      missedReason: reason,
      responseMs: null,
      timeLeftBefore: timeLeftBefore,
      timeLeftAfter: timeLeftAfter,
    );
    emit(
      state.copyWith(
        status: AntonymRushStatus.roundFeedback,
        currentRound: round.copyWith(answered: true),
        combo: 0,
        missedWords: state.missedWords + 1,
        timeLeft: timeLeftAfter,
        lastOutcome: RoundOutcome.missed,
        feedbackText: applyPenalty ? 'Missed! -2s' : 'Missed!',
      ),
    );
    _scheduleNextRound(_missedDelay);
  }

  void onBalloonEscaped(String optionId) {
    final AntonymRound? round = state.currentRound;
    if (!_canResolveRound(round) || state.status != AntonymRushStatus.playing) {
      return;
    }
    final AntonymRound currentRound = round!;
    if (state.escapedOptionIds.contains(optionId)) {
      return;
    }
    final Set<String> escaped = <String>{...state.escapedOptionIds, optionId};
    emit(state.copyWith(escapedOptionIds: escaped));
    final BalloonOption option = currentRound.options.firstWhere(
      (o) => o.id == optionId,
    );
    final bool allEscaped = escaped.length >= currentRound.options.length;
    debugPrint(
      '[AntonymRushCubit] balloon escaped id=$optionId correct=${option.isCorrect} allEscaped=$allEscaped',
    );
    if (option.isCorrect || allEscaped) {
      registerMissedRound(
        reason: option.isCorrect
            ? MissedReason.correctEscaped
            : MissedReason.allEscaped,
      );
    }
  }

  void endGame() {
    if (_ended) return;
    debugPrint('[AntonymRushCubit] endGame');
    if (kDebugMode) {
      debugPrint(
        '[AntonymRoundTelemetry] summary missedReasonCounts='
        'correctEscaped=${_missedReasonCounts[MissedReason.correctEscaped]} '
        'allEscaped=${_missedReasonCounts[MissedReason.allEscaped]} '
        'watchdog=${_missedReasonCounts[MissedReason.watchdog]} '
        'roundTimeout=${_missedReasonCounts[MissedReason.roundTimeout]}',
      );
    }
    _ended = true;
    _nextRoundTimer?.cancel();
    _roundEscapeTimer?.cancel();
    _pendingRoundStartOnResume = false;
    timerManager.cancel();
    emit(
      state.copyWith(
        status: AntonymRushStatus.ended,
        clearRound: true,
        gameResult: _buildResult(),
      ),
    );
  }

  @override
  GameSessionStats? finish() {
    return state.gameResult?.stats;
  }

  void _startRound() {
    if (_ended || state.timeLeft <= 0) {
      endGame();
      return;
    }
    final AntonymRound round = _roundGenerator.generate(
      timeLeft: state.timeLeft,
      wordsSolved: state.wordsSolved,
    );
    final phase = _difficultyService.phaseForTimeLeft(state.timeLeft);
    final bool beginnerRound = round.roundId <= _beginnerRoundCount;
    final speed = _difficultyService.speedFor(
      phase: phase,
      wordsSolved: state.wordsSolved,
      beginnerMode: beginnerRound,
    );
    debugPrint(
      '[AntonymRushCubit] startRound id=${round.roundId} phase=$phase',
    );
    _roundTelemetry[round.roundId] = _RoundTelemetry(
      roundId: round.roundId,
      targetWord: round.targetWord,
      phase: phase,
      pairDifficulty: round.pairDifficulty.name,
      speedSeconds: speed,
      spawnedLaneSnapshot: 'presentation_controlled',
      spawnedYSnapshot: 'presentation_controlled',
    );
    _emitTelemetry(round: round, event: 'round_started');
    emit(
      state.copyWith(
        status: AntonymRushStatus.playing,
        currentRound: round,
        currentSpeed: speed,
        escapedOptionIds: <String>{},
        clearFeedback: true,
      ),
    );
    _scheduleRoundEscape(round);
  }

  void _handleCorrect(AntonymRound round) {
    if (!_markResolved(round.roundId)) return;
    final int responseTime = DateTime.now()
        .difference(round.startedAt)
        .inMilliseconds;
    _responseTimesMs.add(responseTime);
    final int comboMultiplier = (state.combo ~/ 3) + 1;
    final int points = _correctPoints * comboMultiplier;
    final int nextCombo = state.combo + 1;
    _roundEscapeTimer?.cancel();
    debugPrint(
      '[AntonymRushCubit] correct round=${round.roundId} points=$points',
    );
    _emitTelemetry(
      round: round,
      event: 'round_resolved',
      outcome: RoundOutcome.correct,
      responseMs: responseTime,
      timeLeftBefore: state.timeLeft,
      timeLeftAfter: state.timeLeft,
    );
    emit(
      state.copyWith(
        status: AntonymRushStatus.roundFeedback,
        currentRound: round.copyWith(answered: true),
        score: state.score + points,
        combo: nextCombo,
        bestCombo: nextCombo > state.bestCombo ? nextCombo : state.bestCombo,
        totalAttempts: state.totalAttempts + 1,
        correctAnswers: state.correctAnswers + 1,
        wordsSolved: state.wordsSolved + 1,
        lastOutcome: RoundOutcome.correct,
        feedbackText: '+$points',
      ),
    );
    _scheduleNextRound(_correctDelay);
  }

  void _handleWrong(AntonymRound round) {
    if (!_markResolved(round.roundId)) return;
    final int responseTime = DateTime.now()
        .difference(round.startedAt)
        .inMilliseconds;
    _responseTimesMs.add(responseTime);
    _roundEscapeTimer?.cancel();
    debugPrint('[AntonymRushCubit] wrong round=${round.roundId}');
    final int timeLeftBefore = state.timeLeft;
    final int timeLeftAfter = (state.timeLeft - _wrongPenaltySeconds).clamp(
      0,
      60,
    );
    _emitTelemetry(
      round: round,
      event: 'round_resolved',
      outcome: RoundOutcome.wrong,
      responseMs: responseTime,
      timeLeftBefore: timeLeftBefore,
      timeLeftAfter: timeLeftAfter,
    );
    emit(
      state.copyWith(
        status: AntonymRushStatus.roundFeedback,
        currentRound: round.copyWith(answered: true),
        combo: 0,
        totalAttempts: state.totalAttempts + 1,
        wrongAnswers: state.wrongAnswers + 1,
        timeLeft: timeLeftAfter,
        lastOutcome: RoundOutcome.wrong,
        feedbackText: '-3s',
      ),
    );
    _scheduleNextRound(_wrongDelay);
  }

  void _scheduleNextRound(Duration delay) {
    _nextRoundTimer?.cancel();
    _pendingRoundStartOnResume = false;
    if (_ended || state.timeLeft <= 0) {
      endGame();
      return;
    }
    _nextRoundTimer = Timer(delay, _startRound);
  }

  void _scheduleRoundEscape(AntonymRound round) {
    _roundEscapeTimer?.cancel();
    final phase = _difficultyService.phaseForTimeLeft(state.timeLeft);
    final bool beginnerRound = round.roundId <= _beginnerRoundCount;
    final int phaseMinAutoMissMs = switch (phase) {
      DifficultyPhase.early => _earlyMinAutoMissMs,
      DifficultyPhase.mid => _midMinAutoMissMs,
      DifficultyPhase.late => _lateMinAutoMissMs,
    };
    final int minAutoMissMs = beginnerRound
        ? _beginnerMinAutoMissMs
        : phaseMinAutoMissMs;
    final int expectedWindowMs = (state.currentSpeed * 1000).round();
    final int configuredTimeoutMs = expectedWindowMs + _escapeSafetyBufferMs;
    final int autoMissMs = configuredTimeoutMs < minAutoMissMs
        ? minAutoMissMs
        : configuredTimeoutMs;
    final _RoundTelemetry? telemetry = _roundTelemetry[round.roundId];
    if (telemetry != null) {
      telemetry
        ..expectedTappableMs = expectedWindowMs
        ..configuredMissTimeoutMs = configuredTimeoutMs
        ..effectiveAutoMissMs = autoMissMs
        ..roundMaxLifetimeMs = autoMissMs;
    }
    _emitTelemetry(
      round: round,
      event: 'round_escape_scheduled',
      extra:
          'expectedWindowMs=$expectedWindowMs safetyBufferMs=$_escapeSafetyBufferMs configuredTimeoutMs=$configuredTimeoutMs minAutoMissMs=$minAutoMissMs autoMissMs=$autoMissMs',
    );
    _roundEscapeTimer = Timer(Duration(milliseconds: autoMissMs), () {
      final AntonymRound? current = state.currentRound;
      if (current == null ||
          current.roundId != round.roundId ||
          !_canResolveRound(current)) {
        return;
      }
      registerMissedRound(reason: MissedReason.roundTimeout);
    });
  }

  GameResult _buildResult() {
    final int accuracy = _scoringService.calculateAccuracy(
      correctAnswers: state.correctAnswers,
      wrongAnswers: state.wrongAnswers,
      missedAnswers: state.missedWords,
    );
    final int averageResponseMs = _responseTimesMs.isEmpty
        ? 0
        : (_responseTimesMs.reduce((int a, int b) => a + b) /
                  _responseTimesMs.length)
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
    return GameResult(
      stats: stats,
      replayGoal: _replayGoalService.buildGoal(stats),
    );
  }

  @override
  Future<void> close() {
    debugPrint('[AntonymRushCubit] close');
    _nextRoundTimer?.cancel();
    _roundEscapeTimer?.cancel();
    _pendingRoundStartOnResume = false;
    return super.close();
  }

  bool _canResolveRound(AntonymRound? round) {
    if (round == null || round.answered || _ended) {
      return false;
    }
    return !_resolvedRoundIds.contains(round.roundId);
  }

  bool _markResolved(int roundId) {
    if (_resolvedRoundIds.contains(roundId)) {
      return false;
    }
    _resolvedRoundIds.add(roundId);
    return true;
  }

  void _resetMissedReasonCounts() {
    _missedReasonCounts.updateAll((reason, count) => 0);
  }

  BalloonOption? _optionForId(AntonymRound round, String answerId) {
    for (final BalloonOption option in round.options) {
      if (option.id == answerId) {
        return option;
      }
    }
    return null;
  }

  String _formatOptions(AntonymRound? round) {
    if (round == null) return 'none';
    return round.options
        .map(
          (BalloonOption option) =>
              '${option.id}:${option.word}:${option.isCorrect}',
        )
        .join('|');
  }

  void _emitTapTelemetry({
    required AntonymRound round,
    required BalloonOption selected,
    required RoundOutcome expectedOutcome,
    required int scoreBefore,
    required int scoreAfter,
    required int comboBefore,
    required int comboAfter,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[AntonymTapTelemetry] '
      'event=tap_resolved '
      'roundId=${round.roundId} '
      'target=${round.targetWord} '
      'tappedOptionId=${selected.id} '
      'tappedWord=${selected.word} '
      'expectedCorrectWord=${round.correctAnswer} '
      'tappedIsCorrect=${selected.isCorrect} '
      'options=${_formatOptions(round)} '
      'expectedOutcome=${expectedOutcome.name} '
      'recordedOutcome=${state.lastOutcome?.name ?? "none"} '
      'scoreBefore=$scoreBefore '
      'scoreAfter=$scoreAfter '
      'comboBefore=$comboBefore '
      'comboAfter=$comboAfter '
      'status=${state.status.name} '
      'feedbackTransitionActive=${_nextRoundTimer?.isActive ?? false}',
    );
  }

  void _emitIgnoredTapTelemetry({
    required AntonymRound? round,
    required String answerId,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[AntonymTapTelemetry] '
      'event=tap_ignored '
      'reason=$reason '
      'roundId=${round?.roundId ?? -1} '
      'tappedOptionId=$answerId '
      'target=${round?.targetWord ?? "none"} '
      'expectedCorrectWord=${round?.correctAnswer ?? "none"} '
      'options=${_formatOptions(round)} '
      'status=${state.status.name} '
      'lastOutcome=${state.lastOutcome?.name ?? "none"} '
      'feedbackTransitionActive=${_nextRoundTimer?.isActive ?? false} '
      'roundAnswered=${round?.answered ?? false} '
      'roundResolved=${round == null ? false : _resolvedRoundIds.contains(round.roundId)} '
      'ended=$_ended',
    );
  }

  void _emitTelemetry({
    required AntonymRound round,
    required String event,
    RoundOutcome? outcome,
    MissedReason? missedReason,
    int? responseMs,
    int? timeLeftBefore,
    int? timeLeftAfter,
    String? extra,
  }) {
    if (!kDebugMode) return;
    final _RoundTelemetry? t = _roundTelemetry[round.roundId];
    final String msg =
        '[AntonymRoundTelemetry] '
        'event=$event '
        'roundId=${round.roundId} '
        'target=${round.targetWord} '
        'phase=${t?.phase.name ?? "unknown"} '
        'pairDifficulty=${t?.pairDifficulty ?? round.pairDifficulty.name} '
        'spawnY=${t?.spawnedYSnapshot ?? "n/a"} '
        'lanes=${t?.spawnedLaneSnapshot ?? "n/a"} '
        'speedSeconds=${t?.speedSeconds.toStringAsFixed(3) ?? state.currentSpeed.toStringAsFixed(3)} '
        'expectedTappableMs=${t?.expectedTappableMs ?? -1} '
        'roundMaxLifetimeMs=${t?.roundMaxLifetimeMs ?? -1} '
        'configuredMissTimeoutMs=${t?.configuredMissTimeoutMs ?? -1} '
        'effectiveAutoMissMs=${t?.effectiveAutoMissMs ?? -1} '
        'outcome=${outcome?.name ?? "pending"} '
        'missedReason=${missedReason?.name ?? "none"} '
        'responseMs=${responseMs ?? -1} '
        'timeLeftBefore=${timeLeftBefore ?? state.timeLeft} '
        'timeLeftAfter=${timeLeftAfter ?? state.timeLeft}'
        '${extra == null ? "" : " $extra"}';
    debugPrint(msg);
  }
}

class _RoundTelemetry {
  _RoundTelemetry({
    required this.roundId,
    required this.targetWord,
    required this.phase,
    required this.pairDifficulty,
    required this.spawnedYSnapshot,
    required this.spawnedLaneSnapshot,
    required this.speedSeconds,
  });

  final int roundId;
  final String targetWord;
  final DifficultyPhase phase;
  final String pairDifficulty;
  final String spawnedYSnapshot;
  final String spawnedLaneSnapshot;
  final double speedSeconds;
  int? expectedTappableMs;
  int? configuredMissTimeoutMs;
  int? effectiveAutoMissMs;
  int? roundMaxLifetimeMs;
}
