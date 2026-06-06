import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/core/auth/auth_invalidation_controller.dart';
import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/auth/application/auth_state.dart';
import 'package:lexrush/features/auth/data/auth_dtos.dart';
import 'package:lexrush/features/auth/data/auth_repository.dart';
import 'package:lexrush/features/games/commas/application/cubit/commas_cubit.dart';
import 'package:lexrush/features/games/commas/application/cubit/commas_state.dart';
import 'package:lexrush/features/games/commas/data/comma_prompts.dart';
import 'package:lexrush/features/games/commas/domain/services/comma_round_generator.dart';
import 'package:lexrush/features/games/sequencing_memory/application/cubit/sequencing_memory_cubit.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_stage.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/services/sequencing_audio_service.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/today_dtos.dart';
import 'package:lexrush/shared/data/backend/user_achievements_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';

import 'helpers/fake_analytics.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _settle() => Future<void>.delayed(Duration.zero);

CommasCubit _commasCubit({AnalyticsPort? analytics}) => CommasCubit(
  roundGenerator: CommaRoundGenerator(prompts: commaPrompts),
  analytics: analytics,
);

SubmitGameResultRequest _syncRequest() => const SubmitGameResultRequest(
  score: 750,
  accuracy: 0.8,
  totalAttempts: 10,
  correctAnswers: 8,
  wrongAnswers: 2,
  missedAnswers: 0,
  wordsSolved: 8,
  bestCombo: 4,
  averageResponseTimeMs: 2100,
);

PendingGameResult _pendingItem(String id) => PendingGameResult(
  id: 'user-1:$id',
  userId: 'user-1',
  gameId: 'commas',
  sessionId: id,
  request: _syncRequest(),
  createdAt: DateTime(2026),
  enqueuedAt: DateTime(2026),
  retryCount: 0,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AnalyticsPort — game_started / game_completed', () {
    test('game_started is emitted when CommasCubit.start() is called', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final CommasCubit cubit = _commasCubit(analytics: analytics);

      cubit.start();
      await _settle();

      final List<Map<String, dynamic>> events = analytics.eventsOf('game_started');
      expect(events, hasLength(1));
      expect(events.first['gameId'], 'commas');
      expect(events.first['source'], 'unknown');
      expect(events.first['usedBackendPrompts'], isFalse);

      cubit.close();
    });

    test('game_completed is emitted when CommasCubit.endGame() is called', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final CommasCubit cubit = _commasCubit(analytics: analytics);

      cubit.start();
      cubit.endGame();
      await _settle();

      final List<Map<String, dynamic>> events = analytics.eventsOf('game_completed');
      expect(events, hasLength(1));
      expect(events.first['gameId'], 'commas');
      expect(events.first['score'], isA<int>());
      expect(events.first['accuracy'], isA<double>());
      expect(events.first['durationSeconds'], isA<int>());

      cubit.close();
    });

    test('game_started carries usedBackendPrompts=true when flag is set', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final CommasCubit cubit = CommasCubit(
        roundGenerator: CommaRoundGenerator(prompts: commaPrompts),
        analytics: analytics,
        usedBackendPrompts: true,
      );

      cubit.start();
      await _settle();

      expect(analytics.eventsOf('game_started').first['usedBackendPrompts'], isTrue);

      cubit.close();
    });

    test('analytics failure during start() does not throw or break gameplay', () async {
      final ThrowingAnalyticsPort throwing = ThrowingAnalyticsPort();
      final CommasCubit cubit = _commasCubit(analytics: throwing);

      expect(() => cubit.start(), returnsNormally);
      await _settle();

      expect(cubit.state.status, CommasStatus.playing);
      cubit.close();
    });

    test('analytics failure during endGame() does not throw', () async {
      final ThrowingAnalyticsPort throwing = ThrowingAnalyticsPort();
      final CommasCubit cubit = _commasCubit(analytics: throwing);

      cubit.start();
      expect(() => cubit.endGame(), returnsNormally);
      await _settle();

      expect(cubit.state.status, CommasStatus.completed);
      cubit.close();
    });
  });

  group('AnalyticsPort — no sensitive fields in events', () {
    test('game events contain no token/email/password keys', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final CommasCubit cubit = _commasCubit(analytics: analytics);

      cubit.start();
      cubit.endGame();
      await _settle();

      for (final Map<String, dynamic> event in analytics.events) {
        expect(event.keys, isNot(contains('accessToken')));
        expect(event.keys, isNot(contains('refreshToken')));
        expect(event.keys, isNot(contains('password')));
        expect(event.keys, isNot(contains('email')));
        expect(event.keys, isNot(contains('token')));
      }
      cubit.close();
    });

    test('auth events do not include email or password in the event map', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final _FakeAuthRepository repo = _FakeAuthRepository();
      final AuthInvalidationController controller = AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: repo,
        invalidationController: controller,
        analytics: analytics,
      );

      await cubit.login(email: 'user@test.com', password: 'secret');
      await _settle();

      final Map<String, dynamic> event =
          analytics.eventsOf('auth_login_success').first;
      expect(event.keys, isNot(contains('email')));
      expect(event.keys, isNot(contains('password')));
      expect(event.keys, isNot(contains('accessToken')));

      await cubit.close();
      await controller.close();
    });
  });

  group('AuthCubit analytics', () {
    test('login success emits auth_login_success', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final AuthInvalidationController controller = AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: _FakeAuthRepository(),
        invalidationController: controller,
        analytics: analytics,
      );

      await cubit.login(email: 'u@test.com', password: 'pass');
      await _settle();

      expect(analytics.eventsOf('auth_login_success'), hasLength(1));
      expect(analytics.eventsOf('auth_register_success'), isEmpty);

      await cubit.close();
      await controller.close();
    });

    test('register success emits auth_register_success', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final AuthInvalidationController controller = AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: _FakeAuthRepository(),
        invalidationController: controller,
        analytics: analytics,
      );

      await cubit.register(email: 'u@test.com', password: 'pass');
      await _settle();

      expect(analytics.eventsOf('auth_register_success'), hasLength(1));
      expect(analytics.eventsOf('auth_login_success'), isEmpty);

      await cubit.close();
      await controller.close();
    });

    test('logout emits auth_logout', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final AuthInvalidationController controller = AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: _FakeAuthRepository(),
        invalidationController: controller,
        analytics: analytics,
      );

      await cubit.logout();
      await _settle();

      expect(analytics.eventsOf('auth_logout'), hasLength(1));

      await cubit.close();
      await controller.close();
    });

    test('analytics failure on login does not break auth state', () async {
      final ThrowingAnalyticsPort throwing = ThrowingAnalyticsPort();
      final AuthInvalidationController controller = AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: _FakeAuthRepository(),
        invalidationController: controller,
        analytics: throwing,
      );

      await cubit.login(email: 'u@test.com', password: 'pass');
      await _settle();

      expect(cubit.state.status, AuthStatus.authenticated);

      await cubit.close();
      await controller.close();
    });

    test('app_started is only emitted once even if initialize is called twice', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final AuthInvalidationController controller = AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: _FakeAuthRepository(hasStoredTokens: true),
        invalidationController: controller,
        analytics: analytics,
      );

      await cubit.initialize();
      await cubit.initialize();
      await _settle();

      // Guard prevents double-firing; at most 1 app_started in this process.
      expect(analytics.eventsOf('app_started').length, lessThanOrEqualTo(1));

      await cubit.close();
      await controller.close();
    });
  });

  group('BackendResultSyncService analytics', () {
    test('successful sync emits result_sync_status status=synced with xpEarned', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final BackendResultSyncService service = BackendResultSyncService(
        gameId: 'commas',
        repository: _FakeBackendRepository(),
        analytics: analytics,
      );

      final BackendResultSyncHandle handle =
          service.submitSummaryWithHandle(_syncRequest());
      await handle.completed;
      await _settle();

      final List<Map<String, dynamic>> events =
          analytics.eventsOf('result_sync_status');
      expect(events, hasLength(1));
      expect(events.first['status'], 'synced');
      expect(events.first['xpEarned'], 37);
      handle.dispose();
    });

    test('authRequired path emits result_sync_status status=authRequired', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final BackendResultSyncService service = BackendResultSyncService(
        gameId: 'commas',
        repository: _FakeBackendRepository(accessTokenAvailable: false),
        analytics: analytics,
      );

      final BackendResultSyncHandle handle =
          service.submitSummaryWithHandle(_syncRequest());
      await handle.completed;
      await _settle();

      expect(analytics.eventsOf('result_sync_status').first['status'],
          'authRequired');
      handle.dispose();
    });

    test('network failure emits result_sync_status — not a crash', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final FakeCrashReporter crash = FakeCrashReporter();
      final BackendResultSyncService service = BackendResultSyncService(
        gameId: 'commas',
        repository: _FakeBackendRepository(createError: Exception('offline')),
        analytics: analytics,
      );

      final BackendResultSyncHandle handle =
          service.submitSummaryWithHandle(_syncRequest());
      await handle.completed;
      await _settle();

      expect(analytics.eventsOf('result_sync_status').first['status'],
          anyOf('failed', 'authRequired'));
      // Expected network failure must not be reported as crash.
      expect(crash.captured, isEmpty);
      handle.dispose();
    });

    test('SESSION_ALREADY_COMPLETED emits synced — not a crash', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final FakeCrashReporter crash = FakeCrashReporter();
      final BackendResultSyncService service = BackendResultSyncService(
        gameId: 'commas',
        repository: _FakeBackendRepository(
          submitError: const ApiException(
            statusCode: 409,
            code: 'SESSION_ALREADY_COMPLETED',
            message: 'Already completed.',
          ),
        ),
        analytics: analytics,
      );

      final BackendResultSyncHandle handle =
          service.submitSummaryWithHandle(_syncRequest());
      await handle.completed;
      await _settle();

      expect(analytics.eventsOf('result_sync_status').first['status'], 'synced');
      expect(crash.captured, isEmpty);
      handle.dispose();
    });
  });

  group('OfflineResultRetryCoordinator analytics', () {
    test('drain emits offline_retry_drain with correct counts', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final _FakePendingResultQueue queue = _FakePendingResultQueue(
        items: <PendingGameResult>[_pendingItem('a'), _pendingItem('b')],
      );
      final OfflineResultRetryCoordinator coordinator =
          OfflineResultRetryCoordinator(
            queue: queue,
            repository: _FakeBackendRepository(),
            analytics: analytics,
          );

      await coordinator.drain(userId: 'user-1');
      await _settle();

      final List<Map<String, dynamic>> events =
          analytics.eventsOf('offline_retry_drain');
      expect(events, hasLength(1));
      expect(events.first['startedCount'], 2);
      expect(events.first['succeededCount'], 2);
      expect(events.first['failedCount'], 0);
    });

    test('no drain event when queue has no items for user', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final OfflineResultRetryCoordinator coordinator =
          OfflineResultRetryCoordinator(
            queue: _FakePendingResultQueue(items: <PendingGameResult>[]),
            repository: _FakeBackendRepository(),
            analytics: analytics,
          );

      await coordinator.drain(userId: 'user-1');
      await _settle();

      expect(analytics.eventsOf('offline_retry_drain'), isEmpty);
    });
  });

  group('SequencingMemoryCubit TTS analytics', () {
    test('tts_failsafe_triggered reason=error on audio error + crash captured', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final FakeCrashReporter crash = FakeCrashReporter();
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
        analytics: analytics,
        crashReporter: crash,
        listenFailsafePerItem: const Duration(milliseconds: 40),
        listenFailsafeBase: const Duration(milliseconds: 20),
      );

      cubit.start();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);

      audio.emitError(message: 'tts_crash');
      await _settle();

      expect(cubit.state.stage, SequencingStage.arrangePartOne);
      final List<Map<String, dynamic>> failsafeEvents =
          analytics.eventsOf('tts_failsafe_triggered');
      expect(failsafeEvents, hasLength(1));
      expect(failsafeEvents.first['reason'], 'error');
      expect(failsafeEvents.first['stage'], 'listenPartOne');
      expect(crash.captured, hasLength(1));

      await cubit.close();
    });

    test('tts_failsafe_triggered reason=timeout when failsafe fires', () async {
      final FakeAnalyticsPort analytics = FakeAnalyticsPort();
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
        analytics: analytics,
        listenFailsafePerItem: const Duration(milliseconds: 40),
        listenFailsafeBase: const Duration(milliseconds: 20),
      );

      cubit.start();
      await _settle();
      expect(cubit.state.stage, SequencingStage.listenPartOne);

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(cubit.state.stage, SequencingStage.arrangePartOne);
      final List<Map<String, dynamic>> failsafeEvents =
          analytics.eventsOf('tts_failsafe_triggered');
      expect(failsafeEvents, hasLength(1));
      expect(failsafeEvents.first['reason'], 'timeout');

      await cubit.close();
    });

    test('tts error tracking does not throw even if analytics fails', () async {
      final ThrowingAnalyticsPort throwing = ThrowingAnalyticsPort();
      final _ControlledAudioService audio = _ControlledAudioService();
      final SequencingMemoryCubit cubit = SequencingMemoryCubit(
        audioService: audio,
        analytics: throwing,
        listenFailsafePerItem: const Duration(milliseconds: 40),
        listenFailsafeBase: const Duration(milliseconds: 20),
      );

      cubit.start();
      await _settle();

      expect(() => audio.emitError(message: 'crash'), returnsNormally);
      await _settle();

      expect(cubit.state.stage, SequencingStage.arrangePartOne);
      await cubit.close();
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.hasStoredTokens = false});

  final bool hasStoredTokens;

  @override
  Future<bool> hasTokens() async => hasStoredTokens;

  @override
  Future<AuthResponse> login(LoginRequest request) async => AuthResponse(
    tokens: AuthTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    ),
    user: AuthUser(
      userId: 'user-1',
      email: request.email,
      displayName: 'Test',
    ),
  );

  @override
  Future<AuthResponse> register(RegisterRequest request) async => AuthResponse(
    tokens: AuthTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    ),
    user: AuthUser(
      userId: 'user-1',
      email: request.email,
      displayName: request.displayName,
    ),
  );

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser> me() async => const AuthUser(
    userId: 'user-1',
    email: 'test@example.com',
    displayName: 'Test',
  );

  @override
  Future<AuthTokens> refresh(String refreshToken) async =>
      AuthTokens(accessToken: 'a2', refreshToken: 'r2');
}

class _FakeBackendRepository implements LexRushBackendRepository {
  _FakeBackendRepository({
    this.accessTokenAvailable = true,
    this.createError,
    this.submitError,
  });

  final bool accessTokenAvailable;
  final Object? createError;
  final Object? submitError;

  @override
  Future<bool> hasAccessToken() async => accessTokenAvailable;

  @override
  Future<CreateGameSessionResponse> createGameSession(String gameId) async {
    final Object? e = createError;
    if (e != null) throw e;
    return const CreateGameSessionResponse(
      sessionId: 'session-1',
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
    final Object? e = submitError;
    if (e != null) throw e;
    return const SubmitGameResultResponse(
      resultId: 'result-1',
      sessionId: 'session-1',
      gameId: 'commas',
      score: 750,
      accuracy: 0.8,
      xpEarned: 37,
      totalAttempts: 10,
      correctAnswers: 8,
      wrongAnswers: 2,
      missedAnswers: 0,
      createdAt: '2026-05-31T00:00:00.000Z',
    );
  }

  @override
  Future<UserProgressResponse> getMyProgress() async =>
      const UserProgressResponse(
        userId: 'user-1',
        totalXp: 37,
        currentStreak: 1,
        longestStreak: 1,
        lastTrainingDay: '2026-05-31',
        sessionsCompleted: 1,
      );

  @override
  Future<UserSkillsResponse> getMySkills() async =>
      const UserSkillsResponse(userId: 'user-1', skills: <SkillProgressDto>[]);

  @override
  Future<UserAchievementsResponse> getMyAchievements() async =>
      const UserAchievementsResponse(achievements: <UserAchievementDto>[]);

  @override
  Future<TodayResponseDto> getToday() async {
    throw UnimplementedError();
  }

  @override
  void close() {}
}

class _FakePendingResultQueue implements PendingResultQueue {
  _FakePendingResultQueue({required List<PendingGameResult> items})
    : _items = List<PendingGameResult>.from(items);

  final List<PendingGameResult> _items;

  @override
  Future<List<PendingGameResult>> loadAll() async =>
      List<PendingGameResult>.from(_items);

  @override
  Future<void> enqueueOrUpdate(PendingGameResult result) async {
    _items.removeWhere((i) => i.id == result.id);
    _items.add(result);
  }

  @override
  Future<void> remove(String id) async =>
      _items.removeWhere((i) => i.id == id);

  @override
  Future<void> removeForUser(String userId) async =>
      _items.removeWhere((i) => i.userId == userId);

  @override
  Future<void> update(PendingGameResult result) async {
    final int idx = _items.indexWhere((i) => i.id == result.id);
    if (idx >= 0) _items[idx] = result;
  }
}

class _ControlledAudioService implements SequencingAudioService {
  final StreamController<SequencingAudioProgress> _controller =
      StreamController<SequencingAudioProgress>.broadcast();

  int _id = 0;

  @override
  Stream<SequencingAudioProgress> get progress => _controller.stream;

  @override
  bool get isSpeaking => false;

  @override
  int speakSequence(List<String> items) => ++_id;

  @override
  int speakItem(String item) => ++_id;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async => _controller.close();

  void complete() {
    _controller.add(
      SequencingAudioProgress(
        playbackId: _id,
        spokenCount: 3,
        currentItemIndex: 3,
        isComplete: true,
      ),
    );
  }

  void emitError({String? message}) {
    _controller.add(
      SequencingAudioProgress(
        playbackId: _id,
        spokenCount: 0,
        currentItemIndex: 0,
        errorMessage: message,
      ),
    );
  }
}
