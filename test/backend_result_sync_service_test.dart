import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';
import 'package:lexrush/shared/presentation/widgets/result_sync_status_banner.dart';

void main() {
  group('BackendResultSyncService', () {
    test(
      'success emits synced with backend XP and fetches progress/skills',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository();
        final BackendResultSyncService service = BackendResultSyncService(
          gameId: 'commas',
          repository: repository,
        );

        final BackendResultSyncHandle handle = service.submitSummaryWithHandle(
          _request(),
        );
        expect(handle.statusListenable.value.phase, BackendSyncPhase.syncing);

        await handle.completed;

        expect(handle.statusListenable.value.phase, BackendSyncPhase.synced);
        expect(handle.statusListenable.value.xpEarned, 37);
        expect(repository.progressFetches, 1);
        expect(repository.skillsFetches, 1);
        handle.dispose();
      },
    );

    test('duplicate result is treated as already synced', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository(
        submitError: const ApiException(
          statusCode: 409,
          code: 'SESSION_ALREADY_COMPLETED',
          message: 'Session already completed.',
        ),
      );
      final BackendResultSyncService service = BackendResultSyncService(
        gameId: 'commas',
        repository: repository,
      );

      final BackendResultSyncHandle handle = service.submitSummaryWithHandle(
        _request(),
      );
      await handle.completed;

      expect(
        handle.statusListenable.value.phase,
        BackendSyncPhase.alreadySynced,
      );
      expect(repository.progressFetches, 0);
      expect(repository.skillsFetches, 0);
      handle.dispose();
    });

    test('session creation failure emits failed', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository(
        createError: Exception('offline'),
      );
      final BackendResultSyncService service = BackendResultSyncService(
        gameId: 'commas',
        repository: repository,
      );

      final BackendResultSyncHandle handle = service.submitSummaryWithHandle(
        _request(),
      );
      await handle.completed;

      expect(handle.statusListenable.value.phase, BackendSyncPhase.failed);
      handle.dispose();
    });

    test('submit failure emits failed', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository(
        submitError: const ApiException(
          statusCode: 500,
          code: 'SERVER_ERROR',
          message: 'Nope.',
        ),
      );
      final BackendResultSyncService service = BackendResultSyncService(
        gameId: 'commas',
        repository: repository,
      );

      final BackendResultSyncHandle handle = service.submitSummaryWithHandle(
        _request(),
      );
      await handle.completed;

      expect(handle.statusListenable.value.phase, BackendSyncPhase.failed);
      handle.dispose();
    });

    test(
      'logged-out sync emits auth required without creating session',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository(
          accessTokenAvailable: false,
        );
        final BackendResultSyncService service = BackendResultSyncService(
          gameId: 'commas',
          repository: repository,
        );

        final BackendResultSyncHandle handle = service.submitSummaryWithHandle(
          _request(),
        );
        await handle.completed;

        expect(
          handle.statusListenable.value.phase,
          BackendSyncPhase.authRequired,
        );
        expect(repository.createAttempts, 0);
        handle.dispose();
      },
    );
  });

  group('ResultSyncStatusBanner', () {
    testWidgets('renders syncing, synced, duplicate, and failed copy', (
      WidgetTester tester,
    ) async {
      final BackendResultSyncHandle handle = BackendResultSyncHandle();
      await tester.pumpWidget(_Harness(handle: handle));
      expect(find.text('Syncing progress…'), findsOneWidget);

      handle.setStatus(const BackendSyncStatus.synced(xpEarned: 37));
      await tester.pump();
      expect(find.text('Progress synced · +37 XP saved'), findsOneWidget);

      handle.setStatus(const BackendSyncStatus.alreadySynced());
      await tester.pump();
      expect(find.text('Progress synced'), findsOneWidget);

      handle.setStatus(const BackendSyncStatus.failed());
      await tester.pump();
      expect(find.text('Couldn’t sync progress'), findsOneWidget);

      handle.setStatus(const BackendSyncStatus.authRequired());
      await tester.pump();
      expect(find.text('Sign in to save progress'), findsOneWidget);

      handle.dispose();
    });
  });
}

SubmitGameResultRequest _request() {
  return const SubmitGameResultRequest(
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
}

class _Harness extends StatelessWidget {
  const _Harness({required this.handle});

  final BackendResultSyncHandle handle;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: ResultSyncStatusBanner(syncHandle: handle)),
    );
  }
}

class _FakeBackendRepository implements LexRushBackendRepository {
  _FakeBackendRepository({
    this.createError,
    this.submitError,
    this.accessTokenAvailable = true,
  });

  final Object? createError;
  final Object? submitError;
  final bool accessTokenAvailable;
  int createAttempts = 0;
  int progressFetches = 0;
  int skillsFetches = 0;

  @override
  Future<CreateGameSessionResponse> createGameSession(String gameId) async {
    createAttempts += 1;
    final Object? error = createError;
    if (error != null) throw error;
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
    final Object? error = submitError;
    if (error != null) throw error;
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
  Future<UserProgressResponse> getMyProgress() async {
    progressFetches += 1;
    return const UserProgressResponse(
      userId: 'dev-user-001',
      totalXp: 37,
      currentStreak: 1,
      longestStreak: 1,
      lastTrainingDay: '2026-05-31',
      sessionsCompleted: 1,
    );
  }

  @override
  Future<UserSkillsResponse> getMySkills() async {
    skillsFetches += 1;
    return const UserSkillsResponse(
      userId: 'dev-user-001',
      skills: <SkillProgressDto>[],
    );
  }

  @override
  void close() {}

  @override
  Future<bool> hasAccessToken() async => accessTokenAvailable;
}
