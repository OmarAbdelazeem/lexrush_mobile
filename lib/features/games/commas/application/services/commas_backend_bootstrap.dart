import 'dart:async';

import 'package:lexrush/features/games/commas/data/comma_prompt_snapshot_mapper.dart';
import 'package:lexrush/features/games/commas/data/comma_prompts.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_prompt.dart';
import 'package:lexrush/shared/application/services/backend_result_mappers.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';

class CommasBackendBootstrap {
  const CommasBackendBootstrap({
    required LexRushBackendRepository repository,
    PendingResultQueue? pendingQueue,
    String? userId,
    Duration timeout = const Duration(seconds: 2),
    AnalyticsPort? analytics,
  }) : _repository = repository,
       _pendingQueue = pendingQueue,
       _userId = userId,
       _timeout = timeout,
       _analytics = analytics;

  final LexRushBackendRepository _repository;
  final PendingResultQueue? _pendingQueue;
  final String? _userId;
  final Duration _timeout;
  final AnalyticsPort? _analytics;

  Future<CommasBootstrapResult> load() async {
    final bool hasAccessToken = await _repository.hasAccessToken();
    if (!hasAccessToken) {
      unawaited(
        _analytics
            ?.trackBackendPromptBootstrap(
              gameId: BackendGameIds.commas,
              outcome: 'local_logged_out',
            )
            .catchError((_) {}),
      );
      return const CommasBootstrapResult.local(
        fallbackSyncStatus: BackendSyncStatus.authRequired(),
      );
    }

    final BackendResultSyncService syncService = BackendResultSyncService(
      gameId: BackendGameIds.commas,
      repository: _repository,
      pendingQueue: _pendingQueue,
      userId: _userId,
      analytics: _analytics,
    );

    try {
      final CreateGameSessionResponse? session = await syncService
          .startSession()
          .timeout(_timeout);
      final List<CommaPrompt> prompts =
          session == null || session.gameId != BackendGameIds.commas
          ? <CommaPrompt>[]
          : CommaPromptSnapshotMapper.mapSessionPrompts(session.prompts);
      if (prompts.isEmpty) {
        unawaited(
          _analytics
              ?.trackBackendPromptBootstrap(
                gameId: BackendGameIds.commas,
                outcome: session == null
                    ? 'local_network_failure'
                    : 'local_invalid_snapshot',
              )
              .catchError((_) {}),
        );
        return const CommasBootstrapResult.local(
          fallbackSyncStatus: BackendSyncStatus.failed(),
        );
      }
      unawaited(
        _analytics
            ?.trackBackendPromptBootstrap(
              gameId: BackendGameIds.commas,
              outcome: 'backend',
            )
            .catchError((_) {}),
      );
      return CommasBootstrapResult.backend(
        prompts: prompts,
        syncService: syncService,
      );
    } on TimeoutException {
      unawaited(
        _analytics
            ?.trackBackendPromptBootstrap(
              gameId: BackendGameIds.commas,
              outcome: 'local_timeout',
            )
            .catchError((_) {}),
      );
      return const CommasBootstrapResult.local(
        fallbackSyncStatus: BackendSyncStatus.failed(),
      );
    } on Object {
      unawaited(
        _analytics
            ?.trackBackendPromptBootstrap(
              gameId: BackendGameIds.commas,
              outcome: 'local_network_failure',
            )
            .catchError((_) {}),
      );
      return const CommasBootstrapResult.local(
        fallbackSyncStatus: BackendSyncStatus.failed(),
      );
    }
  }
}

class CommasBootstrapResult {
  const CommasBootstrapResult._({
    required this.prompts,
    required this.syncService,
    required this.fallbackSyncStatus,
    required this.usedBackendPrompts,
  });

  const CommasBootstrapResult.local({BackendSyncStatus? fallbackSyncStatus})
    : this._(
        prompts: commaPrompts,
        syncService: null,
        fallbackSyncStatus: fallbackSyncStatus,
        usedBackendPrompts: false,
      );

  const CommasBootstrapResult.backend({
    required List<CommaPrompt> prompts,
    required BackendResultSyncService syncService,
  }) : this._(
         prompts: prompts,
         syncService: syncService,
         fallbackSyncStatus: null,
         usedBackendPrompts: true,
       );

  final List<CommaPrompt> prompts;
  final BackendResultSyncService? syncService;
  final BackendSyncStatus? fallbackSyncStatus;
  final bool usedBackendPrompts;
}
