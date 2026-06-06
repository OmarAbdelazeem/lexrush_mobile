import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/application/services/result_sync_error_classifier.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';

abstract interface class ResultRetryDrainer {
  Future<void> drain({required String userId});
}

class OfflineResultRetryCoordinator implements ResultRetryDrainer {
  OfflineResultRetryCoordinator({
    required PendingResultQueue queue,
    required LexRushBackendRepository repository,
    DateTime Function()? now,
    AnalyticsPort? analytics,
  }) : _queue = queue,
       _repository = repository,
       _now = now ?? DateTime.now,
       _analytics = analytics;

  final PendingResultQueue _queue;
  final LexRushBackendRepository _repository;
  final DateTime Function() _now;
  final AnalyticsPort? _analytics;

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
    int started = 0;
    int succeeded = 0;
    int failed = 0;
    int duplicates = 0;

    for (final PendingGameResult item in items) {
      if (item.userId != userId) continue;
      started++;
      try {
        await _repository.submitGameResult(item.sessionId, item.request);
        await _queue.remove(item.id);
        succeeded++;
      } on Object catch (error) {
        if (ResultSyncErrorClassifier.isTerminalSuccess(error) ||
            ResultSyncErrorClassifier.isValidationOrClientError(error)) {
          await _queue.remove(item.id);
          duplicates++;
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
          failed++;
          continue;
        }
        debugPrint('[OfflineResultRetry] dropped unexpected error: $error');
        await _queue.remove(item.id);
        failed++;
      }
    }

    if (started > 0) {
      unawaited(
        _analytics
            ?.trackOfflineRetryDrain(
              startedCount: started,
              succeededCount: succeeded,
              failedCount: failed,
              removedDuplicateCount: duplicates,
            )
            .catchError((_) {}),
      );
    }
  }
}
