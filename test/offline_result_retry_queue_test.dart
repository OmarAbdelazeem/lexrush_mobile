import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/user_achievements_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('SharedPreferencesPendingResultQueue', () {
    test('stores userId and dedupes by userId and sessionId', () async {
      _setAsyncPreferences(<String, Object>{});
      final SharedPreferencesPendingResultQueue queue =
          SharedPreferencesPendingResultQueue(
            preferences: SharedPreferencesAsync(),
          );

      await queue.enqueueOrUpdate(
        _pending(userId: 'user-1', sessionId: 'session-1', score: 10),
      );
      await queue.enqueueOrUpdate(
        _pending(userId: 'user-1', sessionId: 'session-1', score: 20),
      );
      await queue.enqueueOrUpdate(
        _pending(userId: 'user-2', sessionId: 'session-1', score: 30),
      );

      final List<PendingGameResult> items = await queue.loadAll();

      expect(items, hasLength(2));
      expect(
        items
            .singleWhere((PendingGameResult item) => item.userId == 'user-1')
            .request
            .score,
        20,
      );
      expect(
        items
            .singleWhere((PendingGameResult item) => item.userId == 'user-2')
            .request
            .score,
        30,
      );
    });

    test('corrupt queue JSON does not crash and is cleaned', () async {
      _setAsyncPreferences(<String, Object>{
        SharedPreferencesPendingResultQueue.storageKey: '{nope',
      });
      final SharedPreferencesAsync preferences = SharedPreferencesAsync();
      final SharedPreferencesPendingResultQueue queue =
          SharedPreferencesPendingResultQueue(preferences: preferences);

      final List<PendingGameResult> items = await queue.loadAll();

      expect(items, isEmpty);
      expect(
        await preferences.getString(
          SharedPreferencesPendingResultQueue.storageKey,
        ),
        '[]',
      );
    });

    test('corrupt queue items are ignored and cleaned', () async {
      _setAsyncPreferences(<String, Object>{
        SharedPreferencesPendingResultQueue.storageKey:
            '[{"bad":true}, ${_encoded(_pending())}]',
      });
      final SharedPreferencesPendingResultQueue queue =
          SharedPreferencesPendingResultQueue(
            preferences: SharedPreferencesAsync(),
          );

      final List<PendingGameResult> items = await queue.loadAll();

      expect(items, hasLength(1));
      expect(items.single.userId, 'user-1');
    });
  });

  group('OfflineResultRetryCoordinator', () {
    test('drains only the current user without creating sessions', () async {
      final _MemoryQueue queue = _MemoryQueue(<PendingGameResult>[
        _pending(userId: 'user-1', sessionId: 'session-1'),
        _pending(userId: 'user-2', sessionId: 'session-2'),
      ]);
      final _FakeBackendRepository repository = _FakeBackendRepository();
      final OfflineResultRetryCoordinator coordinator =
          OfflineResultRetryCoordinator(queue: queue, repository: repository);

      await coordinator.drain(userId: 'user-1');

      expect(repository.submittedSessionIds, <String>['session-1']);
      expect(repository.createAttempts, 0);
      expect(queue.items.single.userId, 'user-2');
    });

    test('successful retry removes queued item', () async {
      final _MemoryQueue queue = _MemoryQueue(<PendingGameResult>[_pending()]);
      final OfflineResultRetryCoordinator coordinator =
          OfflineResultRetryCoordinator(
            queue: queue,
            repository: _FakeBackendRepository(),
          );

      await coordinator.drain(userId: 'user-1');

      expect(queue.items, isEmpty);
    });

    test('duplicate retry removes queued item', () async {
      final _MemoryQueue queue = _MemoryQueue(<PendingGameResult>[_pending()]);
      final OfflineResultRetryCoordinator coordinator =
          OfflineResultRetryCoordinator(
            queue: queue,
            repository: _FakeBackendRepository(
              submitError: const ApiException(
                statusCode: 409,
                code: 'SESSION_ALREADY_COMPLETED',
                message: 'Already completed.',
              ),
            ),
          );

      await coordinator.drain(userId: 'user-1');

      expect(queue.items, isEmpty);
    });

    test('retry failure keeps item and increments metadata', () async {
      final DateTime now = DateTime.utc(2026, 6, 5, 12);
      final _MemoryQueue queue = _MemoryQueue(<PendingGameResult>[_pending()]);
      final OfflineResultRetryCoordinator coordinator =
          OfflineResultRetryCoordinator(
            queue: queue,
            repository: _FakeBackendRepository(
              submitError: const ApiException(
                statusCode: 500,
                code: 'SERVER_ERROR',
                message: 'Down.',
              ),
            ),
            now: () => now,
          );

      await coordinator.drain(userId: 'user-1');

      expect(queue.items.single.retryCount, 1);
      expect(queue.items.single.lastAttemptAt, now);
    });

    test('validation error removes queued item', () async {
      final _MemoryQueue queue = _MemoryQueue(<PendingGameResult>[_pending()]);
      final OfflineResultRetryCoordinator coordinator =
          OfflineResultRetryCoordinator(
            queue: queue,
            repository: _FakeBackendRepository(
              submitError: const ApiException(
                statusCode: 400,
                code: 'VALIDATION_ERROR',
                message: 'Bad accuracy.',
              ),
            ),
          );

      await coordinator.drain(userId: 'user-1');

      expect(queue.items, isEmpty);
    });

    test('drain is single-flight', () async {
      final _MemoryQueue queue = _MemoryQueue(<PendingGameResult>[_pending()]);
      final Completer<void> submitCompleter = Completer<void>();
      final _FakeBackendRepository repository = _FakeBackendRepository(
        submitCompleter: submitCompleter,
      );
      final OfflineResultRetryCoordinator coordinator =
          OfflineResultRetryCoordinator(queue: queue, repository: repository);

      final Future<void> first = coordinator.drain(userId: 'user-1');
      final Future<void> second = coordinator.drain(userId: 'user-1');
      await Future<void>.delayed(Duration.zero);

      expect(repository.submittedSessionIds, <String>['session-1']);

      submitCompleter.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(queue.items, isEmpty);
    });

    test('queued JSON keeps decimal accuracy and omits answerEvents', () {
      final Map<String, dynamic> json = _pending().toJson();
      final request = json['request'] as Map<String, dynamic>;

      expect(request['accuracy'], 0.8);
      expect(request.containsKey('answerEvents'), isFalse);
    });
  });
}

void _setAsyncPreferences(Map<String, Object> values) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(values);
}

PendingGameResult _pending({
  String userId = 'user-1',
  String sessionId = 'session-1',
  int score = 750,
}) {
  final DateTime at = DateTime.utc(2026, 6, 5);
  return PendingGameResult(
    id: '$userId:$sessionId',
    userId: userId,
    gameId: 'commas',
    sessionId: sessionId,
    request: _request(score: score),
    createdAt: at,
    enqueuedAt: at,
    retryCount: 0,
  );
}

SubmitGameResultRequest _request({int score = 750}) {
  return SubmitGameResultRequest(
    score: score,
    accuracy: 0.8,
    totalAttempts: 10,
    correctAnswers: 8,
    wrongAnswers: 2,
    missedAnswers: 0,
    wordsSolved: 8,
    bestCombo: 4,
    averageResponseTimeMs: 2100,
  );
}

String _encoded(PendingGameResult item) {
  return jsonEncode(item.toJson());
}

class _MemoryQueue implements PendingResultQueue {
  _MemoryQueue(this.items);

  final List<PendingGameResult> items;

  @override
  Future<void> enqueueOrUpdate(PendingGameResult item) async {
    final int index = items.indexWhere(
      (PendingGameResult existing) =>
          existing.userId == item.userId &&
          existing.sessionId == item.sessionId,
    );
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }
  }

  @override
  Future<List<PendingGameResult>> loadAll() async => List.of(items);

  @override
  Future<void> remove(String id) async {
    items.removeWhere((PendingGameResult item) => item.id == id);
  }

  @override
  Future<void> removeForUser(String userId) async {
    items.removeWhere((PendingGameResult item) => item.userId == userId);
  }

  @override
  Future<void> update(PendingGameResult item) async {
    final int index = items.indexWhere(
      (PendingGameResult existing) => existing.id == item.id,
    );
    if (index != -1) items[index] = item;
  }
}

class _FakeBackendRepository implements LexRushBackendRepository {
  _FakeBackendRepository({this.submitError, this.submitCompleter});

  final Object? submitError;
  final Completer<void>? submitCompleter;
  final List<String> submittedSessionIds = <String>[];
  int createAttempts = 0;

  @override
  Future<CreateGameSessionResponse> createGameSession(String gameId) async {
    createAttempts += 1;
    return const CreateGameSessionResponse(
      sessionId: 'created-session',
      gameId: 'commas',
      difficulty: 1,
      status: 'created',
      timeLimitSeconds: 60,
      contentVersion: 'v1',
      prompts: <SessionPromptDto>[],
    );
  }

  @override
  Future<SubmitGameResultResponse> submitGameResult(
    String sessionId,
    SubmitGameResultRequest request,
  ) async {
    submittedSessionIds.add(sessionId);
    final Completer<void>? completer = submitCompleter;
    if (completer != null) await completer.future;
    final Object? error = submitError;
    if (error != null) throw error;
    return SubmitGameResultResponse(
      resultId: 'result-$sessionId',
      sessionId: sessionId,
      gameId: 'commas',
      score: request.score,
      accuracy: request.accuracy,
      xpEarned: 37,
      totalAttempts: request.totalAttempts,
      correctAnswers: request.correctAnswers,
      wrongAnswers: request.wrongAnswers,
      missedAnswers: request.missedAnswers,
      createdAt: '2026-06-05T00:00:00.000Z',
    );
  }

  @override
  Future<UserProgressResponse> getMyProgress() async {
    throw UnimplementedError();
  }

  @override
  Future<UserSkillsResponse> getMySkills() async {
    throw UnimplementedError();
  }

  @override
  Future<UserAchievementsResponse> getMyAchievements() async {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasAccessToken() async => true;

  @override
  void close() {}
}
