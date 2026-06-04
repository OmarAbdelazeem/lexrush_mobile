import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/application/services/result_sync_error_classifier.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';

abstract interface class ResultRetryDrainer {
  Future<void> drain({required String userId});
}

class OfflineResultRetryCoordinator implements ResultRetryDrainer {
  OfflineResultRetryCoordinator({
    required PendingResultQueue queue,
    required LexRushBackendRepository repository,
    DateTime Function()? now,
  }) : _queue = queue,
       _repository = repository,
       _now = now ?? DateTime.now;

  final PendingResultQueue _queue;
  final LexRushBackendRepository _repository;
  final DateTime Function() _now;

  Future<void>? _drainInFlight;

  @override
  Future<void> drain({required String userId}) {
    final Future<void>? inFlight = _drainInFlight;
    if (inFlight != null) return inFlight;

    final Future<void> drain = _drain(userId: userId);
    _drainInFlight = drain;
    unawaited(
      drain.whenComplete(() {
        if (identical(_drainInFlight, drain)) {
          _drainInFlight = null;
        }
      }),
    );
    return drain;
  }

  Future<void> _drain({required String userId}) async {
    final List<PendingGameResult> items = await _queue.loadAll();
    for (final PendingGameResult item in items) {
      if (item.userId != userId) continue;
      try {
        await _repository.submitGameResult(item.sessionId, item.request);
        await _queue.remove(item.id);
      } on Object catch (error) {
        if (ResultSyncErrorClassifier.isTerminalSuccess(error) ||
            ResultSyncErrorClassifier.isValidationOrClientError(error)) {
          await _queue.remove(item.id);
          continue;
        }
        if (ResultSyncErrorClassifier.isRetryable(error) ||
            ResultSyncErrorClassifier.isAuthRequired(error)) {
          await _queue.update(
            item.copyWith(
              retryCount: item.retryCount + 1,
              lastAttemptAt: _now(),
            ),
          );
          continue;
        }
        debugPrint('[OfflineResultRetry] dropped unexpected error: $error');
        await _queue.remove(item.id);
      }
    }
  }
}
