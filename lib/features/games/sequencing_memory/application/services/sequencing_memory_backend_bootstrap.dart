import 'dart:async';

import 'package:lexrush/features/games/sequencing_memory/data/sequencing_prompt_snapshot_mapper.dart';
import 'package:lexrush/features/games/sequencing_memory/data/sequencing_prompts.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_prompt.dart';
import 'package:lexrush/shared/application/services/backend_result_mappers.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';

class SequencingMemoryBackendBootstrap {
  const SequencingMemoryBackendBootstrap({
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

  Future<SequencingMemoryBootstrapResult> load() async {
    final bool hasAccessToken = await _repository.hasAccessToken();
    if (!hasAccessToken) {
      return const SequencingMemoryBootstrapResult.local(
        fallbackSyncStatus: BackendSyncStatus.authRequired(),
        createResultSyncOnFinish: false,
      );
    }

    final BackendResultSyncService syncService = BackendResultSyncService(
      gameId: BackendGameIds.sequencingMemory,
      repository: _repository,
      pendingQueue: _pendingQueue,
      userId: _userId,
    );

    try {
      final CreateGameSessionResponse? session = await syncService
          .startSession()
          .timeout(_timeout);
      if (session == null ||
          session.gameId != BackendGameIds.sequencingMemory) {
        return const SequencingMemoryBootstrapResult.local(
          createResultSyncOnFinish: true,
        );
      }

      final List<SequencingPrompt> prompts =
          SequencingPromptSnapshotMapper.mapSessionPrompts(session.prompts);
      if (prompts.isEmpty) {
        return const SequencingMemoryBootstrapResult.local(
          fallbackSyncStatus: BackendSyncStatus.failed(),
          createResultSyncOnFinish: false,
        );
      }

      return SequencingMemoryBootstrapResult.backend(
        prompts: prompts,
        syncService: syncService,
      );
    } on Object {
      return const SequencingMemoryBootstrapResult.local(
        createResultSyncOnFinish: true,
      );
    }
  }
}

class SequencingMemoryBootstrapResult {
  const SequencingMemoryBootstrapResult._({
    required this.prompts,
    required this.syncService,
    required this.fallbackSyncStatus,
    required this.usedBackendPrompts,
    required this.createResultSyncOnFinish,
  });

  const SequencingMemoryBootstrapResult.local({
    BackendSyncStatus? fallbackSyncStatus,
    bool createResultSyncOnFinish = false,
  }) : this._(
         prompts: sequencingPrompts,
         syncService: null,
         fallbackSyncStatus: fallbackSyncStatus,
         usedBackendPrompts: false,
         createResultSyncOnFinish: createResultSyncOnFinish,
       );

  const SequencingMemoryBootstrapResult.backend({
    required List<SequencingPrompt> prompts,
    required BackendResultSyncService syncService,
  }) : this._(
         prompts: prompts,
         syncService: syncService,
         fallbackSyncStatus: null,
         usedBackendPrompts: true,
         createResultSyncOnFinish: false,
       );

  final List<SequencingPrompt> prompts;
  final BackendResultSyncService? syncService;
  final BackendSyncStatus? fallbackSyncStatus;
  final bool usedBackendPrompts;
  final bool createResultSyncOnFinish;
}
