import 'package:flutter/foundation.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

class BackendResultSyncService {
  BackendResultSyncService({
    required String gameId,
    required LexRushBackendRepository repository,
  }) : _gameId = gameId,
       _repository = repository;

  final String _gameId;
  final LexRushBackendRepository _repository;

  Future<String?>? _sessionIdFuture;
  String? _sessionId;
  bool _submissionTerminal = false;

  UserProgressResponse? latestProgress;
  UserSkillsResponse? latestSkills;

  void startSession() {
    _sessionIdFuture ??= _createSession();
  }

  Future<void> submitSummary(SubmitGameResultRequest request) async {
    if (_submissionTerminal) return;

    final String? sessionId = await (_sessionIdFuture ??= _createSession());
    if (sessionId == null) {
      debugPrint('[BackendResultSync] $_gameId skipped: no backend session');
      return;
    }

    try {
      await _repository.submitGameResult(sessionId, request);
      latestProgress = await _repository.getMyProgress();
      latestSkills = await _repository.getMySkills();
      _submissionTerminal = true;
      // TODO: Route sync and gameplay telemetry through a shared logger.
      debugPrint(
        '[BackendResultSync] $_gameId synced; totalXp=${latestProgress?.totalXp} '
        'skills=${latestSkills?.skills.length}',
      );
    } on ApiException catch (error) {
      if (error.isSessionAlreadyCompleted) {
        _submissionTerminal = true;
        debugPrint('[BackendResultSync] $_gameId session already completed');
        return;
      }
      debugPrint('[BackendResultSync] $_gameId submit failed: $error');
    } on Object catch (error) {
      debugPrint('[BackendResultSync] $_gameId submit failed: $error');
    }
  }

  Future<String?> _createSession() async {
    try {
      final CreateGameSessionResponse response = await _repository
          .createGameSession(_gameId);
      _sessionId = response.sessionId;
      debugPrint('[BackendResultSync] $_gameId session created: $_sessionId');
      return _sessionId;
    } on Object catch (error) {
      debugPrint(
        '[BackendResultSync] $_gameId session creation failed: $error',
      );
      return null;
    }
  }
}
