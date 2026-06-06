import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/application/services/result_sync_error_classifier.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';

enum BackendSyncPhase {
  idle,
  syncing,
  synced,
  alreadySynced,
  failed,
  authRequired,
}

class BackendSyncStatus {
  const BackendSyncStatus({required this.phase, this.xpEarned});

  const BackendSyncStatus.idle() : this(phase: BackendSyncPhase.idle);

  const BackendSyncStatus.syncing() : this(phase: BackendSyncPhase.syncing);

  const BackendSyncStatus.synced({int? xpEarned})
    : this(phase: BackendSyncPhase.synced, xpEarned: xpEarned);

  const BackendSyncStatus.alreadySynced()
    : this(phase: BackendSyncPhase.alreadySynced);

  const BackendSyncStatus.failed() : this(phase: BackendSyncPhase.failed);

  const BackendSyncStatus.authRequired()
    : this(phase: BackendSyncPhase.authRequired);

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
    PendingResultQueue? pendingQueue,
    String? userId,
    DateTime Function()? now,
    AnalyticsPort? analytics,
  }) : _gameId = gameId,
       _repository = repository,
       _pendingQueue = pendingQueue,
       _userId = userId,
       _now = now ?? DateTime.now,
       _analytics = analytics;

  final String _gameId;
  final LexRushBackendRepository _repository;
  final PendingResultQueue? _pendingQueue;
  final String? _userId;
  final DateTime Function() _now;
  final AnalyticsPort? _analytics;

  Future<CreateGameSessionResponse?>? _sessionFuture;
  CreateGameSessionResponse? _sessionResponse;
  String? _sessionId;
  bool _submissionTerminal = false;

  UserProgressResponse? latestProgress;
  UserSkillsResponse? latestSkills;

  Future<CreateGameSessionResponse?> startSession() {
    _sessionFuture ??= _createSession();
    return _sessionFuture!;
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

    if (!await _repository.hasAccessToken()) {
      handle.setStatus(const BackendSyncStatus.authRequired());
      unawaited(
        _analytics
            ?.trackResultSyncStatus(gameId: _gameId, status: 'authRequired')
            .catchError((_) {}),
      );
      handle.complete();
      return;
    }

    final CreateGameSessionResponse? session = await startSession();
    final String? sessionId = session?.sessionId;
    if (sessionId == null) {
      debugPrint('[BackendResultSync] $_gameId skipped: no backend session');
      final bool hasToken = await _repository.hasAccessToken();
      final BackendSyncStatus status = hasToken
          ? const BackendSyncStatus.failed()
          : const BackendSyncStatus.authRequired();
      handle.setStatus(status);
      unawaited(
        _analytics
            ?.trackResultSyncStatus(
              gameId: _gameId,
              status: hasToken ? 'failed' : 'authRequired',
            )
            .catchError((_) {}),
      );
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
      debugPrint(
        '[BackendResultSync] $_gameId synced; totalXp=${latestProgress?.totalXp} '
        'skills=${latestSkills?.skills.length}',
      );
      unawaited(
        _analytics
            ?.trackResultSyncStatus(
              gameId: _gameId,
              status: 'synced',
              xpEarned: response.xpEarned,
            )
            .catchError((_) {}),
      );
    } on ApiException catch (error) {
      if (error.isSessionAlreadyCompleted) {
        _submissionTerminal = true;
        handle.setStatus(const BackendSyncStatus.alreadySynced());
        debugPrint('[BackendResultSync] $_gameId session already completed');
        // SESSION_ALREADY_COMPLETED is a handled success — not reported as crash.
        unawaited(
          _analytics
              ?.trackResultSyncStatus(gameId: _gameId, status: 'synced')
              .catchError((_) {}),
        );
        handle.complete();
        return;
      }
      if (error.isAuthRequired) {
        handle.setStatus(const BackendSyncStatus.authRequired());
        unawaited(
          _analytics
              ?.trackResultSyncStatus(
                gameId: _gameId,
                status: 'authRequired',
              )
              .catchError((_) {}),
        );
        handle.complete();
        return;
      }
      await _tryEnqueueRetryable(error, request, sessionId);
      handle.setStatus(const BackendSyncStatus.failed());
      debugPrint('[BackendResultSync] $_gameId submit failed: $error');
      final bool enqueued = ResultSyncErrorClassifier.isRetryable(error);
      unawaited(
        _analytics
            ?.trackResultSyncStatus(
              gameId: _gameId,
              status: enqueued ? 'queued' : 'failed',
            )
            .catchError((_) {}),
      );
    } on Object catch (error) {
      handle.setStatus(const BackendSyncStatus.failed());
      debugPrint('[BackendResultSync] $_gameId submit failed: $error');
      unawaited(
        _analytics
            ?.trackResultSyncStatus(gameId: _gameId, status: 'failed')
            .catchError((_) {}),
      );
    } finally {
      handle.complete();
    }
  }

  Future<CreateGameSessionResponse?> _createSession() async {
    try {
      final CreateGameSessionResponse response = await _repository
          .createGameSession(_gameId);
      _sessionResponse = response;
      _sessionId = response.sessionId;
      debugPrint('[BackendResultSync] $_gameId session created: $_sessionId');
      return _sessionResponse;
    } on ApiException catch (error) {
      if (error.isAuthRequired) return null;
      debugPrint(
        '[BackendResultSync] $_gameId session creation failed: $error',
      );
      return null;
    } on Object catch (error) {
      debugPrint(
        '[BackendResultSync] $_gameId session creation failed: $error',
      );
      return null;
    }
  }

  Future<void> _tryEnqueueRetryable(
    Object error,
    SubmitGameResultRequest request,
    String sessionId,
  ) async {
    try {
      final PendingResultQueue? queue = _pendingQueue;
      final String? userId = _userId;
      if (queue == null || userId == null || userId.isEmpty) return;
      if (!ResultSyncErrorClassifier.isRetryable(error)) return;

      final DateTime now = _now();
      await queue.enqueueOrUpdate(
        PendingGameResult(
          id: '$userId:$sessionId',
          userId: userId,
          gameId: _gameId,
          sessionId: sessionId,
          request: request,
          createdAt: now,
          enqueuedAt: now,
          retryCount: 0,
        ),
      );
    } on Object catch (queueError) {
      debugPrint('[BackendResultSync] $_gameId enqueue failed: $queueError');
    }
  }
}
