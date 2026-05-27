import 'package:flutter/foundation.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';

class CommasBackendSyncService {
  CommasBackendSyncService({required LexRushBackendRepository repository})
    : _repository = repository;

  static const String gameId = 'commas';

  final LexRushBackendRepository _repository;

  Future<String?>? _sessionIdFuture;
  String? _sessionId;
  bool _submissionTerminal = false;

  UserProgressResponse? latestProgress;
  UserSkillsResponse? latestSkills;

  void startSession() {
    _sessionIdFuture ??= _createSession();
  }

  Future<void> submitResult(CommasGameResult result) async {
    if (_submissionTerminal) return;

    final String? sessionId = await (_sessionIdFuture ??= _createSession());
    if (sessionId == null) {
      debugPrint('[CommasBackendSync] skipped result sync: no backend session');
      return;
    }

    try {
      final SubmitGameResultRequest request = buildSummaryRequest(result);
      await _repository.submitGameResult(sessionId, request);
      latestProgress = await _repository.getMyProgress();
      latestSkills = await _repository.getMySkills();
      _submissionTerminal = true;
      debugPrint(
        '[CommasBackendSync] synced result; totalXp=${latestProgress?.totalXp} '
        'skills=${latestSkills?.skills.length}',
      );
    } on ApiException catch (error) {
      if (error.isSessionAlreadyCompleted) {
        _submissionTerminal = true;
        debugPrint('[CommasBackendSync] session already completed');
        return;
      }
      debugPrint('[CommasBackendSync] result sync failed: $error');
    } on Object catch (error) {
      debugPrint('[CommasBackendSync] result sync failed: $error');
    }
  }

  static SubmitGameResultRequest buildSummaryRequest(CommasGameResult result) {
    final GameSessionStats stats = result.summary.stats;
    return SubmitGameResultRequest(
      score: stats.score,
      accuracy: stats.accuracy / 100,
      totalAttempts: stats.totalAttempts,
      correctAnswers: stats.correctAnswers,
      wrongAnswers: stats.missedWords,
      missedAnswers: 0,
      wordsSolved: stats.wordsSolved,
      bestCombo: stats.bestCombo,
      averageResponseTimeMs: stats.averageResponseTimeMs,
    );
  }

  Future<String?> _createSession() async {
    try {
      final CreateGameSessionResponse response = await _repository
          .createGameSession(gameId);
      _sessionId = response.sessionId;
      debugPrint('[CommasBackendSync] session created: $_sessionId');
      return _sessionId;
    } on Object catch (error) {
      debugPrint('[CommasBackendSync] session creation failed: $error');
      return null;
    }
  }
}
