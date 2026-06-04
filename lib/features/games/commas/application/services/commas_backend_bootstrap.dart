import 'dart:async';

import 'package:lexrush/features/games/commas/data/comma_prompt_snapshot_mapper.dart';
import 'package:lexrush/features/games/commas/data/comma_prompts.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_prompt.dart';
import 'package:lexrush/shared/application/services/backend_result_mappers.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';

class CommasBackendBootstrap {
  const CommasBackendBootstrap({
    required LexRushBackendRepository repository,
    Duration timeout = const Duration(seconds: 2),
  }) : _repository = repository,
       _timeout = timeout;

  final LexRushBackendRepository _repository;
  final Duration _timeout;

  Future<CommasBootstrapResult> load() async {
    final bool hasAccessToken = await _repository.hasAccessToken();
    if (!hasAccessToken) {
      return const CommasBootstrapResult.local(
        fallbackSyncStatus: BackendSyncStatus.authRequired(),
      );
    }

    final BackendResultSyncService syncService = BackendResultSyncService(
      gameId: BackendGameIds.commas,
      repository: _repository,
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
        return const CommasBootstrapResult.local(
          fallbackSyncStatus: BackendSyncStatus.failed(),
        );
      }
      return CommasBootstrapResult.backend(
        prompts: prompts,
        syncService: syncService,
      );
    } on Object {
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
