import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexrush/features/games/commas/application/cubit/commas_state.dart';
import 'package:lexrush/features/games/commas/data/comma_prompts.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_insertion_point.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_prompt.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_round_result.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_token.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';
import 'package:lexrush/features/games/commas/domain/services/comma_round_generator.dart';
import 'package:lexrush/features/games/commas/domain/services/comma_scoring_service.dart';
import 'package:lexrush/shared/application/cubits/base_game_session_cubit.dart';
import 'package:lexrush/shared/application/services/backend_result_mappers.dart';
import 'package:lexrush/shared/application/services/replay_goal_service.dart';
import 'package:lexrush/shared/application/services/scoring_service.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';
import 'package:lexrush/shared/domain/contracts/lexrush_game_controller.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';

typedef CommasClock = DateTime Function();

class CommasCubit extends BaseGameSessionCubit<CommasState>
    implements LexRushGameController {
  CommasCubit({
    CommaRoundGenerator? roundGenerator,
    CommaScoringService scoringService = const CommaScoringService(),
    ScoringService xpScoringService = const ScoringService(),
    ReplayGoalService replayGoalService = const ReplayGoalService(),
    CommasClock? clock,
    AnalyticsPort? analytics,
    String gameStartedSource = 'unknown',
    bool usedBackendPrompts = false,
  }) : _roundGenerator =
           roundGenerator ?? CommaRoundGenerator(prompts: commaPrompts),
       _scoringService = scoringService,
       _xpScoringService = xpScoringService,
       _replayGoalService = replayGoalService,
       _clock = clock ?? DateTime.now,
       _analytics = analytics,
       _gameStartedSource = gameStartedSource,
       _usedBackendPrompts = usedBackendPrompts,
       super(CommasState.initial());

  final CommaRoundGenerator _roundGenerator;
  final CommaScoringService _scoringService;
  final ScoringService _xpScoringService;
  final ReplayGoalService _replayGoalService;
  final CommasClock _clock;
  final AnalyticsPort? _analytics;
  final String _gameStartedSource;
  final bool _usedBackendPrompts;

  final List<int> _allResponseTimesMs = <int>[];
  final List<int> _currentResponseTimesMs = <int>[];
  Timer? _feedbackTimer;
  Timer? _nextPromptTimer;
  DateTime? _promptStartedAt;
  DateTime? _sessionStartedAt;
  bool _ended = false;
  bool _currentPromptRecorded = false;
  bool _pendingNextPromptOnResume = false;

  static const int sessionSeconds = 60;
  static const Duration _feedbackDuration = Duration(milliseconds: 420);
  static const Duration _promptCompleteDuration = Duration(milliseconds: 850);

  @override
  void start() {
    debugPrint('[CommasCubit] start');
    _sessionStartedAt = DateTime.now();
    _ended = false;
    _feedbackTimer?.cancel();
    _nextPromptTimer?.cancel();
    _pendingNextPromptOnResume = false;
    _currentPromptRecorded = false;
    _allResponseTimesMs.clear();
    _currentResponseTimesMs.clear();
    _roundGenerator.reset();
    emit(CommasState.initial().copyWith(status: CommasStatus.playing));
    timerManager.start(
      durationSeconds: sessionSeconds,
      onTick: _handleTick,
      onFinished: endGame,
    );
    _loadNextPrompt();
    unawaited(
      _analytics
          ?.trackGameStarted(
            gameId: BackendGameIds.commas,
            source: _gameStartedSource,
            usedBackendPrompts: _usedBackendPrompts,
          )
          .catchError((_) {}),
    );
  }

  @override
  void pause() {
    if (_ended || state.status == CommasStatus.paused) return;
    debugPrint('[CommasCubit] pause');
    timerManager.pause();
    if (_nextPromptTimer?.isActive ?? false) {
      _pendingNextPromptOnResume = true;
    }
    _feedbackTimer?.cancel();
    _nextPromptTimer?.cancel();
    emit(state.copyWith(status: CommasStatus.paused));
  }

  @override
  void resume() {
    if (_ended || state.status != CommasStatus.paused) return;
    debugPrint('[CommasCubit] resume');
    emit(
      state.copyWith(
        status: state.promptCompleted
            ? CommasStatus.sentenceComplete
            : CommasStatus.playing,
      ),
    );
    timerManager.resume(onTick: _handleTick, onFinished: endGame);
    if (_pendingNextPromptOnResume) {
      _pendingNextPromptOnResume = false;
      _scheduleNextPrompt();
    }
  }

  @override
  void restart() {
    debugPrint('[CommasCubit] restart');
    timerManager.cancel();
    start();
  }

  @override
  void submitAnswer(String answerId) {
    final int? afterTokenIndex = int.tryParse(answerId);
    if (afterTokenIndex == null) return;
    submitGap(afterTokenIndex);
  }

  void submitGap(int afterTokenIndex) {
    if (_ended ||
        state.status == CommasStatus.paused ||
        state.status == CommasStatus.completed ||
        state.promptCompleted) {
      return;
    }
    final CommaPrompt? prompt = state.currentPrompt;
    if (prompt == null) return;
    if (state.placedCommaIndexes.contains(afterTokenIndex)) {
      debugPrint('[CommasCubit] ignored already placed gap=$afterTokenIndex');
      return;
    }

    final Set<int> correctIndexes = prompt.insertionPoints
        .map((point) => point.afterTokenIndex)
        .toSet();
    if (correctIndexes.contains(afterTokenIndex)) {
      _handleCorrectGap(afterTokenIndex);
    } else {
      _handleWrongGap(afterTokenIndex);
    }
  }

  void endGame() {
    if (_ended) return;
    debugPrint('[CommasCubit] endGame');
    _ended = true;
    _feedbackTimer?.cancel();
    _nextPromptTimer?.cancel();
    _pendingNextPromptOnResume = false;
    timerManager.cancel();
    _recordCurrentPromptIfNeeded();
    final CommasGameResult result = _buildResult();
    emit(
      state.copyWith(
        status: CommasStatus.completed,
        clearCurrentPrompt: true,
        tokens: <CommaToken>[],
        result: result,
      ),
    );
    final int elapsed =
        _sessionStartedAt != null
            ? DateTime.now().difference(_sessionStartedAt!).inSeconds
            : sessionSeconds;
    unawaited(
      _analytics
          ?.trackGameCompleted(
            gameId: BackendGameIds.commas,
            score: result.summary.stats.score,
            accuracy: result.summary.stats.accuracy / 100.0,
            durationSeconds: elapsed,
            usedBackendPrompts: _usedBackendPrompts,
          )
          .catchError((_) {}),
    );
  }

  @override
  GameSessionStats? finish() => state.result?.summary.stats;

  void _handleTick(int secondsLeft) {
    emit(state.copyWith(timeLeft: secondsLeft));
    if (secondsLeft <= 0) endGame();
  }

  void _loadNextPrompt() {
    if (_ended || state.timeLeft <= 0) {
      endGame();
      return;
    }
    final CommaPrompt prompt = _roundGenerator.nextPrompt(
      completedPrompts: state.sentencesCompleted,
      timeLeft: state.timeLeft,
    );
    final List<CommaToken> tokens = _tokensFor(prompt);
    _promptStartedAt = _clock();
    _currentResponseTimesMs.clear();
    _currentPromptRecorded = false;
    emit(
      state.copyWith(
        status: CommasStatus.playing,
        currentPrompt: prompt,
        tokens: tokens,
        placedCommaIndexes: <int>{},
        wrongGapIndexes: <int>[],
        remainingCommaCount: prompt.insertionPoints.length,
        clearFeedbackText: true,
        clearPromptExplanation: true,
        clearFlashGap: true,
        promptCompleted: false,
      ),
    );
  }

  List<CommaToken> _tokensFor(CommaPrompt prompt) {
    final Set<int> requiredIndexes = prompt.insertionPoints
        .map((CommaInsertionPoint point) => point.afterTokenIndex)
        .toSet();
    final List<String> words = prompt.displayTextWithoutCommas.split(' ');
    return words.asMap().entries.map((MapEntry<int, String> entry) {
      return CommaToken(
        text: entry.value,
        index: entry.key,
        commaRequiredAfter: requiredIndexes.contains(entry.key),
        commaPlacedAfter: false,
      );
    }).toList();
  }

  void _handleCorrectGap(int afterTokenIndex) {
    _feedbackTimer?.cancel();
    final int responseMs = _promptStartedAt == null
        ? 0
        : _clock().difference(_promptStartedAt!).inMilliseconds;
    _allResponseTimesMs.add(responseMs);
    _currentResponseTimesMs.add(responseMs);
    final Set<int> placed = <int>{...state.placedCommaIndexes, afterTokenIndex};
    final List<CommaToken> tokens = state.tokens.map((CommaToken token) {
      return token.index == afterTokenIndex
          ? token.copyWith(commaPlacedAfter: true)
          : token;
    }).toList();
    final int nextCombo = state.combo + 1;
    final CommaPrompt? prompt = state.currentPrompt;
    final int remaining = (prompt?.insertionPoints.length ?? 0) - placed.length;
    final bool completed = remaining == 0;
    final int points =
        CommaScoringService.correctCommaPoints +
        (completed ? CommaScoringService.promptCompleteBonus : 0);
    emit(
      state.copyWith(
        status: completed
            ? CommasStatus.sentenceComplete
            : CommasStatus.correctFeedback,
        score: state.score + points,
        combo: nextCombo,
        bestCombo: nextCombo > state.bestCombo ? nextCombo : state.bestCombo,
        totalAttempts: state.totalAttempts + 1,
        correctTaps: state.correctTaps + 1,
        placedCommaIndexes: placed,
        tokens: tokens,
        remainingCommaCount: remaining,
        feedbackText: completed ? 'Sentence complete +100' : '+100',
        promptExplanation: completed ? prompt?.explanation : null,
        clearFlashGap: true,
        promptCompleted: completed,
        sentencesCompleted: completed
            ? state.sentencesCompleted + 1
            : state.sentencesCompleted,
      ),
    );
    if (completed) {
      _recordCurrentPromptIfNeeded();
      _scheduleNextPrompt();
    } else {
      _scheduleFeedbackClear();
    }
  }

  void _handleWrongGap(int afterTokenIndex) {
    _feedbackTimer?.cancel();
    timerManager.applyPenaltySeconds(
      CommaScoringService.wrongTapPenaltySeconds,
    );
    final int nextTimeLeft = timerManager.secondsLeft;
    emit(
      state.copyWith(
        status: CommasStatus.wrongFeedback,
        timeLeft: nextTimeLeft,
        combo: 0,
        totalAttempts: state.totalAttempts + 1,
        wrongTaps: state.wrongTaps + 1,
        wrongGapIndexes: <int>[...state.wrongGapIndexes, afterTokenIndex],
        feedbackText: 'Not there -3s',
        flashGapAfterTokenIndex: afterTokenIndex,
      ),
    );
    if (nextTimeLeft <= 0) {
      endGame();
      return;
    }
    _scheduleFeedbackClear();
  }

  void _scheduleFeedbackClear() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(_feedbackDuration, () {
      if (_ended || state.status == CommasStatus.paused) return;
      emit(
        state.copyWith(
          status: CommasStatus.playing,
          clearFeedbackText: true,
          clearFlashGap: true,
        ),
      );
    });
  }

  void _scheduleNextPrompt() {
    _nextPromptTimer?.cancel();
    _pendingNextPromptOnResume = false;
    if (_ended || state.timeLeft <= 0) {
      endGame();
      return;
    }
    _nextPromptTimer = Timer(_promptCompleteDuration, _loadNextPrompt);
  }

  void _recordCurrentPromptIfNeeded() {
    if (_currentPromptRecorded) return;
    final CommaPrompt? prompt = state.currentPrompt;
    if (prompt == null) return;
    if (state.placedCommaIndexes.isEmpty &&
        state.wrongGapIndexes.isEmpty &&
        !state.promptCompleted) {
      return;
    }
    _currentPromptRecorded = true;
    final List<int> placed = state.placedCommaIndexes.toList()..sort();
    final CommaRoundResult result = CommaRoundResult(
      prompt: prompt,
      placedCommaIndexes: placed,
      wrongGapIndexes: state.wrongGapIndexes,
      completed: state.promptCompleted,
      responseTimesMs: List<int>.from(_currentResponseTimesMs),
    );
    emit(state.copyWith(review: <CommaRoundResult>[...state.review, result]));
  }

  CommasGameResult _buildResult() {
    final int accuracy = _scoringService.accuracy(
      correctTaps: state.correctTaps,
      wrongTaps: state.wrongTaps,
    );
    final int averageResponseMs = _allResponseTimesMs.isEmpty
        ? 0
        : (_allResponseTimesMs.reduce((int a, int b) => a + b) /
                  _allResponseTimesMs.length)
              .round();
    final int xp = _xpScoringService.calculateXp(
      wordsSolved: state.sentencesCompleted,
      bestCombo: state.bestCombo,
      accuracy: accuracy,
    );
    final GameSessionStats stats = GameSessionStats(
      score: state.score,
      accuracy: accuracy,
      bestCombo: state.bestCombo,
      xpEarned: xp,
      totalAttempts: state.totalAttempts,
      correctAnswers: state.correctTaps,
      wordsSolved: state.sentencesCompleted,
      missedWords: state.wrongTaps,
      averageResponseTimeMs: averageResponseMs,
    );
    return CommasGameResult(
      summary: GameResult(
        stats: stats,
        replayGoal: _replayGoalService.buildGoal(stats),
      ),
      review: state.review,
    );
  }

  @override
  Future<void> close() {
    debugPrint('[CommasCubit] close');
    _feedbackTimer?.cancel();
    _nextPromptTimer?.cancel();
    _pendingNextPromptOnResume = false;
    return super.close();
  }
}
