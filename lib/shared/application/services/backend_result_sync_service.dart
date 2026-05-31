import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

enum BackendSyncPhase { idle, syncing, synced, alreadySynced, failed }

class BackendSyncStatus {
  const BackendSyncStatus({required this.phase, this.xpEarned});

  const BackendSyncStatus.idle() : this(phase: BackendSyncPhase.idle);

  const BackendSyncStatus.syncing() : this(phase: BackendSyncPhase.syncing);

  const BackendSyncStatus.synced({int? xpEarned})
    : this(phase: BackendSyncPhase.synced, xpEarned: xpEarned);

  const BackendSyncStatus.alreadySynced()
    : this(phase: BackendSyncPhase.alreadySynced);

  const BackendSyncStatus.failed() : this(phase: BackendSyncPhase.failed);

  final BackendSyncPhase phase;
  final int? xpEarned;
}

class BackendResultSyncHandle {
  BackendResultSyncHandle()
    : _notifier = ValueNotifier<BackendSyncStatus>(
        const BackendSyncStatus.syncing(),
      );

  final ValueNotifier<BackendSyncStatus> _notifier;
  final Completer<void> _completed = Completer<void>();
  bool _disposed = false;

  ValueListenable<BackendSyncStatus> get statusListenable => _notifier;

  Future<void> get completed => _completed.future;

  void setStatus(BackendSyncStatus status) {
    if (_disposed) return;
    _notifier.value = status;
  }

  void complete() {
    if (!_completed.isCompleted) {
      _completed.complete();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _notifier.dispose();
  }
}

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
    final BackendResultSyncHandle handle = submitSummaryWithHandle(request);
    await handle.completed;
  }

  BackendResultSyncHandle submitSummaryWithHandle(
    SubmitGameResultRequest request,
  ) {
    final BackendResultSyncHandle handle = BackendResultSyncHandle();
    unawaited(_submitSummary(request, handle));
    return handle;
  }

  Future<void> _submitSummary(
    SubmitGameResultRequest request,
    BackendResultSyncHandle handle,
  ) async {
    if (_submissionTerminal) {
      handle.setStatus(const BackendSyncStatus.alreadySynced());
      handle.complete();
      return;
    }

    final String? sessionId = await (_sessionIdFuture ??= _createSession());
    if (sessionId == null) {
      debugPrint('[BackendResultSync] $_gameId skipped: no backend session');
      handle.setStatus(const BackendSyncStatus.failed());
      handle.complete();
      return;
    }

    try {
      final SubmitGameResultResponse response = await _repository
          .submitGameResult(sessionId, request);
      latestProgress = await _repository.getMyProgress();
      latestSkills = await _repository.getMySkills();
      _submissionTerminal = true;
      handle.setStatus(BackendSyncStatus.synced(xpEarned: response.xpEarned));
      // TODO: Route sync and gameplay telemetry through a shared logger.
      debugPrint(
        '[BackendResultSync] $_gameId synced; totalXp=${latestProgress?.totalXp} '
        'skills=${latestSkills?.skills.length}',
      );
    } on ApiException catch (error) {
      if (error.isSessionAlreadyCompleted) {
        _submissionTerminal = true;
        handle.setStatus(const BackendSyncStatus.alreadySynced());
        debugPrint('[BackendResultSync] $_gameId session already completed');
        handle.complete();
        return;
      }
      handle.setStatus(const BackendSyncStatus.failed());
      debugPrint('[BackendResultSync] $_gameId submit failed: $error');
    } on Object catch (error) {
      handle.setStatus(const BackendSyncStatus.failed());
      debugPrint('[BackendResultSync] $_gameId submit failed: $error');
    } finally {
      handle.complete();
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
