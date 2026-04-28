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
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';

class AntonymRushCubit extends BaseGameSessionCubit<AntonymRushState>
    implements LexRushGameController {
  AntonymRushCubit({
    AntonymRoundGenerator? roundGenerator,
    AntonymDifficultyService? difficultyService,
    ScoringService? scoringService,
    ReplayGoalService? replayGoalService,
  })  : _difficultyService = difficultyService ?? const AntonymDifficultyService(),
        _scoringService = scoringService ?? const ScoringService(),
        _replayGoalService = replayGoalService ?? const ReplayGoalService(),
        _roundGenerator = roundGenerator ??
            AntonymRoundGenerator(
              pairs: antonymPairs,
              difficultyService: difficultyService ?? const AntonymDifficultyService(),
            ),
        super(AntonymRushState.initial());

  final AntonymDifficultyService _difficultyService;
  final ScoringService _scoringService;
  final ReplayGoalService _replayGoalService;
  final AntonymRoundGenerator _roundGenerator;
  final List<int> _responseTimesMs = <int>[];
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

  @override
  void start() {
    debugPrint('[AntonymRushCubit] start');
    _ended = false;
    _responseTimesMs.clear();
    _roundGenerator.reset();
    _nextRoundTimer?.cancel();
    _roundEscapeTimer?.cancel();
    _pendingRoundStartOnResume = false;
    final phase = _difficultyService.phaseForTimeLeft(60);
    final speed = _difficultyService.speedFor(phase: phase, wordsSolved: 0);
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
    if (round == null || round.answered || _ended || state.status != AntonymRushStatus.playing) {
      return;
    }
    final BalloonOption selected = round.options.firstWhere((o) => o.id == answerId);
    if (selected.isCorrect) {
      _handleCorrect(round);
    } else {
      _handleWrong(round);
    }
  }

  void registerMissedRound() {
    final AntonymRound? round = state.currentRound;
    if (round == null || round.answered || _ended) return;
    debugPrint('[AntonymRushCubit] missed round=${round.roundId}');
    final bool applyPenalty = round.roundId > 3;
    _roundEscapeTimer?.cancel();
    emit(
      state.copyWith(
        status: AntonymRushStatus.roundFeedback,
        currentRound: round.copyWith(answered: true),
        combo: 0,
        missedWords: state.missedWords + 1,
        timeLeft: applyPenalty ? (state.timeLeft - _missedPenaltySeconds).clamp(0, 60) : state.timeLeft,
        lastOutcome: RoundOutcome.missed,
        feedbackText: applyPenalty ? 'Missed! -2s' : 'Missed!',
      ),
    );
    _scheduleNextRound(_missedDelay);
  }

  void onBalloonEscaped(String optionId) {
    final AntonymRound? round = state.currentRound;
    if (round == null || round.answered || _ended || state.status != AntonymRushStatus.playing) {
      return;
    }
    if (state.escapedOptionIds.contains(optionId)) {
      return;
    }
    final Set<String> escaped = <String>{...state.escapedOptionIds, optionId};
    emit(state.copyWith(escapedOptionIds: escaped));
    final BalloonOption option = round.options.firstWhere((o) => o.id == optionId);
    final bool allEscaped = escaped.length >= round.options.length;
    debugPrint('[AntonymRushCubit] balloon escaped id=$optionId correct=${option.isCorrect} allEscaped=$allEscaped');
    if (option.isCorrect || allEscaped) {
      registerMissedRound();
    }
  }

  void endGame() {
    if (_ended) return;
    debugPrint('[AntonymRushCubit] endGame');
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
    final speed = _difficultyService.speedFor(
      phase: phase,
      wordsSolved: state.wordsSolved,
    );
    debugPrint('[AntonymRushCubit] startRound id=${round.roundId} phase=$phase');
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
    final int responseTime = DateTime.now().difference(round.startedAt).inMilliseconds;
    _responseTimesMs.add(responseTime);
    final int comboMultiplier = (state.combo ~/ 3) + 1;
    final int points = _correctPoints * comboMultiplier;
    final int nextCombo = state.combo + 1;
    _roundEscapeTimer?.cancel();
    debugPrint('[AntonymRushCubit] correct round=${round.roundId} points=$points');
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
    final int responseTime = DateTime.now().difference(round.startedAt).inMilliseconds;
    _responseTimesMs.add(responseTime);
    _roundEscapeTimer?.cancel();
    debugPrint('[AntonymRushCubit] wrong round=${round.roundId}');
    emit(
      state.copyWith(
        status: AntonymRushStatus.roundFeedback,
        currentRound: round.copyWith(answered: true),
        combo: 0,
        totalAttempts: state.totalAttempts + 1,
        wrongAnswers: state.wrongAnswers + 1,
        timeLeft: (state.timeLeft - _wrongPenaltySeconds).clamp(0, 60),
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
    final int ms = ((state.currentSpeed * 1000) + 250).round().clamp(2200, 8000);
    debugPrint('[AntonymRushCubit] schedule round escape round=${round.roundId} afterMs=$ms');
    _roundEscapeTimer = Timer(Duration(milliseconds: ms), () {
      final AntonymRound? current = state.currentRound;
      if (current == null || current.roundId != round.roundId || current.answered) return;
      registerMissedRound();
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
        : (_responseTimesMs.reduce((int a, int b) => a + b) / _responseTimesMs.length).round();
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
    return GameResult(stats: stats, replayGoal: _replayGoalService.buildGoal(stats));
  }

  @override
  Future<void> close() {
    debugPrint('[AntonymRushCubit] close');
    _nextRoundTimer?.cancel();
    _roundEscapeTimer?.cancel();
    _pendingRoundStartOnResume = false;
    return super.close();
  }
}
