import 'dart:async';

import 'package:lexrush/features/games/association/data/association_prompt_snapshot_mapper.dart';
import 'package:lexrush/features/games/association/data/association_prompts.dart';
import 'package:lexrush/features/games/association/domain/entities/association_prompt.dart';
import 'package:lexrush/shared/application/services/backend_result_mappers.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';

class AssociationBackendBootstrap {
  const AssociationBackendBootstrap({
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

  Future<AssociationBootstrapResult> load() async {
    final bool hasAccessToken = await _repository.hasAccessToken();
    if (!hasAccessToken) {
      unawaited(
        _analytics
            ?.trackBackendPromptBootstrap(
              gameId: BackendGameIds.association,
              outcome: 'local_logged_out',
            )
            .catchError((_) {}),
      );
      return const AssociationBootstrapResult.local(
        fallbackSyncStatus: BackendSyncStatus.authRequired(),
        createResultSyncOnFinish: false,
      );
    }

    final BackendResultSyncService syncService = BackendResultSyncService(
      gameId: BackendGameIds.association,
      repository: _repository,
      pendingQueue: _pendingQueue,
      userId: _userId,
      analytics: _analytics,
    );

    try {
      final CreateGameSessionResponse? session = await syncService
          .startSession()
          .timeout(_timeout);
      if (session == null || session.gameId != BackendGameIds.association) {
        unawaited(
          _analytics
              ?.trackBackendPromptBootstrap(
                gameId: BackendGameIds.association,
                outcome: 'local_network_failure',
              )
              .catchError((_) {}),
        );
        return const AssociationBootstrapResult.local(
          createResultSyncOnFinish: true,
        );
      }

      final List<AssociationPrompt> prompts =
          AssociationPromptSnapshotMapper.mapSessionPrompts(session.prompts);
      if (prompts.isEmpty) {
        unawaited(
          _analytics
              ?.trackBackendPromptBootstrap(
                gameId: BackendGameIds.association,
                outcome: 'local_invalid_snapshot',
              )
              .catchError((_) {}),
        );
        return const AssociationBootstrapResult.local(
          fallbackSyncStatus: BackendSyncStatus.failed(),
          createResultSyncOnFinish: false,
        );
      }

      unawaited(
        _analytics
            ?.trackBackendPromptBootstrap(
              gameId: BackendGameIds.association,
              outcome: 'backend',
            )
            .catchError((_) {}),
      );
      return AssociationBootstrapResult.backend(
        prompts: prompts,
        syncService: syncService,
      );
    } on TimeoutException {
      unawaited(
        _analytics
            ?.trackBackendPromptBootstrap(
              gameId: BackendGameIds.association,
              outcome: 'local_timeout',
            )
            .catchError((_) {}),
      );
      return const AssociationBootstrapResult.local(
        createResultSyncOnFinish: true,
      );
    } on Object {
      unawaited(
        _analytics
            ?.trackBackendPromptBootstrap(
              gameId: BackendGameIds.association,
              outcome: 'local_network_failure',
            )
            .catchError((_) {}),
      );
      return const AssociationBootstrapResult.local(
        createResultSyncOnFinish: true,
      );
    }
  }
}

class AssociationBootstrapResult {
  const AssociationBootstrapResult._({
    required this.prompts,
    required this.syncService,
    required this.fallbackSyncStatus,
    required this.usedBackendPrompts,
    required this.createResultSyncOnFinish,
  });

  const AssociationBootstrapResult.local({
    BackendSyncStatus? fallbackSyncStatus,
    bool createResultSyncOnFinish = false,
  }) : this._(
         prompts: associationPrompts,
         syncService: null,
         fallbackSyncStatus: fallbackSyncStatus,
         usedBackendPrompts: false,
         createResultSyncOnFinish: createResultSyncOnFinish,
       );

  const AssociationBootstrapResult.backend({
    required List<AssociationPrompt> prompts,
    required BackendResultSyncService syncService,
  }) : this._(
         prompts: prompts,
         syncService: syncService,
         fallbackSyncStatus: null,
         usedBackendPrompts: true,
         createResultSyncOnFinish: false,
       );

  final List<AssociationPrompt> prompts;
  final BackendResultSyncService? syncService;
  final BackendSyncStatus? fallbackSyncStatus;
  final bool usedBackendPrompts;
  final bool createResultSyncOnFinish;
}
