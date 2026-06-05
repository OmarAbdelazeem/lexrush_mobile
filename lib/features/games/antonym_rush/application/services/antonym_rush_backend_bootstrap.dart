import 'dart:async';

import 'package:lexrush/features/games/antonym_rush/data/antonym_pairs.dart';
import 'package:lexrush/features/games/antonym_rush/data/antonym_prompt_snapshot_mapper.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_pair.dart';
import 'package:lexrush/shared/application/services/backend_result_mappers.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';

class AntonymRushBackendBootstrap {
  const AntonymRushBackendBootstrap({
    required LexRushBackendRepository repository,
    PendingResultQueue? pendingQueue,
    String? userId,
    Duration timeout = const Duration(seconds: 2),
  }) : _repository = repository,
       _pendingQueue = pendingQueue,
       _userId = userId,
       _timeout = timeout;

  final LexRushBackendRepository _repository;
  final PendingResultQueue? _pendingQueue;
  final String? _userId;
  final Duration _timeout;

  Future<AntonymRushBootstrapResult> load() async {
    final bool hasAccessToken = await _repository.hasAccessToken();
    if (!hasAccessToken) {
      return const AntonymRushBootstrapResult.local(
        fallbackSyncStatus: BackendSyncStatus.authRequired(),
        createResultSyncOnFinish: false,
      );
    }

    final BackendResultSyncService syncService = BackendResultSyncService(
      gameId: BackendGameIds.antonymRush,
      repository: _repository,
      pendingQueue: _pendingQueue,
      userId: _userId,
    );

    try {
      final CreateGameSessionResponse? session = await syncService
          .startSession()
          .timeout(_timeout);
      if (session == null || session.gameId != BackendGameIds.antonymRush) {
        return const AntonymRushBootstrapResult.local(
          createResultSyncOnFinish: true,
        );
      }

      final List<AntonymPair> prompts =
          AntonymPromptSnapshotMapper.mapSessionPrompts(session.prompts);
      if (prompts.isEmpty) {
        return const AntonymRushBootstrapResult.local(
          fallbackSyncStatus: BackendSyncStatus.failed(),
          createResultSyncOnFinish: false,
        );
      }

      return AntonymRushBootstrapResult.backend(
        prompts: prompts,
        syncService: syncService,
      );
    } on Object {
      return const AntonymRushBootstrapResult.local(
        createResultSyncOnFinish: true,
      );
    }
  }
}

class AntonymRushBootstrapResult {
  const AntonymRushBootstrapResult._({
    required this.prompts,
    required this.syncService,
    required this.fallbackSyncStatus,
    required this.usedBackendPrompts,
    required this.createResultSyncOnFinish,
  });

  const AntonymRushBootstrapResult.local({
    BackendSyncStatus? fallbackSyncStatus,
    bool createResultSyncOnFinish = false,
  }) : this._(
         prompts: antonymPairs,
         syncService: null,
         fallbackSyncStatus: fallbackSyncStatus,
         usedBackendPrompts: false,
         createResultSyncOnFinish: createResultSyncOnFinish,
       );

  const AntonymRushBootstrapResult.backend({
    required List<AntonymPair> prompts,
    required BackendResultSyncService syncService,
  }) : this._(
         prompts: prompts,
         syncService: syncService,
         fallbackSyncStatus: null,
         usedBackendPrompts: true,
         createResultSyncOnFinish: false,
       );

  final List<AntonymPair> prompts;
  final BackendResultSyncService? syncService;
  final BackendSyncStatus? fallbackSyncStatus;
  final bool usedBackendPrompts;
  final bool createResultSyncOnFinish;
}
