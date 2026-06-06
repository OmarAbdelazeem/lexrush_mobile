import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/sequencing_memory/application/services/sequencing_memory_backend_bootstrap.dart';
import 'package:lexrush/features/games/sequencing_memory/data/sequencing_prompt_snapshot_mapper.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_difficulty.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/services/sequencing_round_generator.dart';
import 'package:lexrush/shared/application/services/backend_result_mappers.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/today_dtos.dart';
import 'package:lexrush/shared/data/backend/user_achievements_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

void main() {
  group('SequencingPromptSnapshotMapper', () {
    test('maps partOne correctly', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt()],
      );
      expect(prompts, hasLength(1));
      final SequencingRoundGenerator generator = SequencingRoundGenerator(
        prompts: prompts,
        preservePromptOrder: true,
      );
      final round = generator.generate();
      expect(round.partOne, <String>['Wake up', 'Brush teeth']);
    });

    test('maps partTwo correctly', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt()],
      );
      final SequencingRoundGenerator generator = SequencingRoundGenerator(
        prompts: prompts,
        preservePromptOrder: true,
      );
      final round = generator.generate();
      expect(round.partTwo, <String>['Make coffee', 'Check messages']);
    });

    test('maps combined correctly', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt()],
      );
      expect(prompts.single.items, <String>[
        'Wake up',
        'Brush teeth',
        'Make coffee',
        'Check messages',
      ]);
    });

    test('maps items (id + text) when present', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt()],
      );
      final backendItems = prompts.single.backendItems;
      expect(backendItems, isNotNull);
      expect(backendItems!, hasLength(4));
      expect(backendItems.map((i) => i.id).toList(), <String>[
        'a',
        'b',
        'c',
        'd',
      ]);
      expect(backendItems.map((i) => i.text).toList(), <String>[
        'Wake up',
        'Brush teeth',
        'Make coffee',
        'Check messages',
      ]);
    });

    test('maps correctOrder when present and valid', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt()],
      );
      expect(prompts.single.correctOrderIds, <String>['a', 'b', 'c', 'd']);
    });

    test('maps memoryHint', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt()],
      );
      expect(
        prompts.single.memoryHint,
        'Picture each action as it happens in order.',
      );
    });

    test('maps explanation', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt()],
      );
      expect(
        prompts.single.explanation,
        'Daily routines are easier to remember when you imagine each action happening in order.',
      );
    });

    test('preserves orderIndex ordering', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            orderIndex: 2,
            promptId: 'second',
            partOne: <String>['Step C', 'Step D'],
            partTwo: <String>['Step E', 'Step F'],
          ),
          _prompt(
            orderIndex: 1,
            promptId: 'first',
            partOne: <String>['Step A', 'Step B'],
            partTwo: <String>['Step C', 'Step D'],
          ),
        ],
      );
      expect(prompts, hasLength(2));
      expect(prompts[0].id, 'first');
      expect(prompts[1].id, 'second');
    });

    test('maps difficulty tag to SequencingDifficulty', () {
      final beginner = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt(difficultyTag: 'beginner', difficulty: 1)],
      );
      final medium = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            difficultyTag: 'medium',
            difficulty: 2,
            partOne: <String>['A', 'B', 'C'],
            partTwo: <String>['D', 'E', 'F'],
          ),
        ],
      );
      final hard = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            difficultyTag: 'hard',
            difficulty: 3,
            partOne: <String>['A', 'B', 'C', 'D'],
            partTwo: <String>['E', 'F', 'G', 'H'],
          ),
        ],
      );
      expect(beginner.single.difficulty, SequencingDifficulty.beginner);
      expect(beginner.single.beginnerSafe, isTrue);
      expect(medium.single.difficulty, SequencingDifficulty.medium);
      expect(medium.single.beginnerSafe, isFalse);
      expect(hard.single.difficulty, SequencingDifficulty.hard);
    });

    test('skips snapshot where combined != partOne + partTwo', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            combined: <String>['Wake up', 'WRONG', 'Make coffee', 'Check messages'],
          ),
        ],
      );
      expect(prompts, isEmpty);
    });

    test('skips snapshot where partOne and partTwo have unequal lengths', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          SessionPromptDto(
            orderIndex: 0,
            promptId: 'p',
            contentJson: <String, dynamic>{
              'partOne': <String>['A', 'B', 'C'],
              'partTwo': <String>['D', 'E'],
              'combined': <String>['A', 'B', 'C', 'D', 'E'],
            },
            answerJson: <String, dynamic>{},
            difficulty: 1,
            difficultyTag: 'beginner',
            ruleType: 'sequence_order',
            skillTags: <String>[],
            explanation: null,
          ),
        ],
      );
      expect(prompts, isEmpty);
    });

    test('skips snapshot where items texts do not match combined', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            items: <Map<String, dynamic>>[
              <String, dynamic>{'id': 'a', 'text': 'Wake up'},
              <String, dynamic>{'id': 'b', 'text': 'WRONG'},
              <String, dynamic>{'id': 'c', 'text': 'Make coffee'},
              <String, dynamic>{'id': 'd', 'text': 'Check messages'},
            ],
          ),
        ],
      );
      expect(prompts, isEmpty);
    });

    test('skips snapshot where correctOrder references unknown item id', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(correctOrder: <String>['a', 'b', 'c', 'MISSING']),
        ],
      );
      expect(prompts, isEmpty);
    });

    test('skips snapshot where correctOrder resolves to wrong combined order', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(correctOrder: <String>['d', 'c', 'b', 'a']),
        ],
      );
      expect(prompts, isEmpty);
    });

    test('skips snapshot with empty partOne', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            partOne: <String>[],
            partTwo: <String>['Make coffee', 'Check messages'],
            combined: <String>['Make coffee', 'Check messages'],
          ),
        ],
      );
      expect(prompts, isEmpty);
    });

    test('skips snapshot with missing partTwo', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          SessionPromptDto(
            orderIndex: 0,
            promptId: 'p',
            contentJson: <String, dynamic>{
              'partOne': <String>['A', 'B'],
            },
            answerJson: <String, dynamic>{},
            difficulty: 1,
            difficultyTag: 'beginner',
            ruleType: 'sequence_order',
            skillTags: <String>[],
            explanation: null,
          ),
        ],
      );
      expect(prompts, isEmpty);
    });

    test('unknown ruleType does not crash', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt(ruleType: 'unknown_future_rule_type')],
      );
      expect(prompts, hasLength(1));
    });

    test('null ruleType does not crash', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[_prompt(ruleType: null)],
      );
      expect(prompts, hasLength(1));
    });

    test('skips invalid snapshots in a mixed list', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            orderIndex: 0,
            promptId: 'valid',
            partOne: <String>['Step A', 'Step B'],
            partTwo: <String>['Step C', 'Step D'],
          ),
          _prompt(
            orderIndex: 1,
            promptId: 'invalid-combined',
            combined: <String>['Step A', 'WRONG', 'Step C', 'Step D'],
          ),
        ],
      );
      expect(prompts, hasLength(1));
      expect(prompts.single.id, 'valid');
    });

    test('backend generator preserves order and recycles prompts', () {
      final prompts = SequencingPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            orderIndex: 0,
            promptId: 'first',
            partOne: <String>['A1', 'A2'],
            partTwo: <String>['A3', 'A4'],
          ),
          _prompt(
            orderIndex: 1,
            promptId: 'second',
            partOne: <String>['B1', 'B2'],
            partTwo: <String>['B3', 'B4'],
          ),
          _prompt(
            orderIndex: 2,
            promptId: 'third',
            partOne: <String>['C1', 'C2'],
            partTwo: <String>['C3', 'C4'],
          ),
        ],
      );
      final generator = SequencingRoundGenerator(
        prompts: prompts,
        preservePromptOrder: true,
      );
      final r1 = generator.generate();
      final r2 = generator.generate();
      final r3 = generator.generate();
      final recycled = generator.generate();

      expect(r1.partOne, <String>['A1', 'A2']);
      expect(r2.partOne, <String>['B1', 'B2']);
      expect(r3.partOne, <String>['C1', 'C2']);
      expect(recycled.partOne, <String>['A1', 'A2']);
    });
  });

  group('SequencingMemoryBackendBootstrap', () {
    test(
      'logged out uses local prompts and does not create backend session',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository(
          accessTokenAvailable: false,
        );

        final result = await SequencingMemoryBackendBootstrap(
          repository: repository,
        ).load();

        expect(result.usedBackendPrompts, isFalse);
        expect(result.syncService, isNull);
        expect(result.createResultSyncOnFinish, isFalse);
        expect(result.fallbackSyncStatus?.phase, BackendSyncPhase.authRequired);
        expect(repository.createAttempts, 0);
      },
    );

    test(
      'session creation failure uses local prompts and allows result-time sync',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository(
          createError: Exception('offline'),
        );

        final result = await SequencingMemoryBackendBootstrap(
          repository: repository,
        ).load();
        repository.createError = null;

        final resultTimeSync = BackendResultSyncService(
          gameId: BackendGameIds.sequencingMemory,
          repository: repository,
        );
        final handle = resultTimeSync.submitSummaryWithHandle(_request());
        await handle.completed;

        expect(result.usedBackendPrompts, isFalse);
        expect(result.syncService, isNull);
        expect(result.fallbackSyncStatus, isNull);
        expect(result.createResultSyncOnFinish, isTrue);
        expect(repository.createAttempts, 2);
        expect(repository.submitAttempts, 1);
        expect(handle.statusListenable.value.phase, BackendSyncPhase.synced);
        handle.dispose();
      },
    );

    test('slow session creation falls back locally for gameplay', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository(
        createDelay: const Duration(milliseconds: 50),
      );

      final result = await SequencingMemoryBackendBootstrap(
        repository: repository,
        timeout: const Duration(milliseconds: 10),
      ).load();

      expect(result.usedBackendPrompts, isFalse);
      expect(result.createResultSyncOnFinish, isTrue);
      expect(result.fallbackSyncStatus, isNull);
    });

    test(
      'invalid (empty-mapped) backend prompt session is not reused for result sync',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository(
          prompts: <SessionPromptDto>[
            _prompt(combined: <String>['WRONG', 'combined', 'order', 'invalid']),
          ],
        );

        final result = await SequencingMemoryBackendBootstrap(
          repository: repository,
        ).load();

        expect(result.usedBackendPrompts, isFalse);
        expect(result.syncService, isNull);
        expect(result.createResultSyncOnFinish, isFalse);
        expect(result.fallbackSyncStatus?.phase, BackendSyncPhase.failed);
        expect(repository.createAttempts, 1);
        expect(repository.submitAttempts, 0);
      },
    );

    test(
      'valid backend prompts reuse run-scoped session for submission',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository();

        final result = await SequencingMemoryBackendBootstrap(
          repository: repository,
        ).load();
        final handle = result.syncService!.submitSummaryWithHandle(_request());
        await handle.completed;

        expect(result.usedBackendPrompts, isTrue);
        expect(result.createResultSyncOnFinish, isFalse);
        expect(repository.createAttempts, 1);
        expect(repository.submitAttempts, 1);
        expect(repository.submittedSessionIds, <String>['session-1']);
        expect(handle.statusListenable.value.phase, BackendSyncPhase.synced);
        handle.dispose();
      },
    );

    test('no answerEvents key in submitted request', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository();

      final result = await SequencingMemoryBackendBootstrap(
        repository: repository,
      ).load();
      final handle = result.syncService!.submitSummaryWithHandle(_request());
      await handle.completed;

      expect(
        repository.submittedRequests.single.toJson().containsKey('answerEvents'),
        isFalse,
      );
      handle.dispose();
    });

    test('decimal accuracy 0..1 preserved in submission', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository();

      final result = await SequencingMemoryBackendBootstrap(
        repository: repository,
      ).load();
      final handle = result.syncService!.submitSummaryWithHandle(_request());
      await handle.completed;

      final double accuracy = repository.submittedRequests.single.accuracy;
      expect(accuracy, greaterThanOrEqualTo(0.0));
      expect(accuracy, lessThanOrEqualTo(1.0));
      expect(accuracy, 0.75);
      handle.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Builds a valid SessionPromptDto. When items/correctOrder are not provided,
// they are derived automatically from the combined list so the mapper accepts
// the prompt regardless of what partOne/partTwo/combined are supplied.
SessionPromptDto _prompt({
  int orderIndex = 0,
  String promptId = 'prompt-1',
  List<String>? partOne,
  List<String>? partTwo,
  List<String>? combined,
  List<Map<String, dynamic>>? items,
  List<String>? correctOrder,
  int difficulty = 1,
  String difficultyTag = 'beginner',
  String? ruleType = 'sequence_order',
  String? explanation =
      'Daily routines are easier to remember when you imagine each action happening in order.',
}) {
  final List<String> p1 = partOne ?? <String>['Wake up', 'Brush teeth'];
  final List<String> p2 = partTwo ?? <String>['Make coffee', 'Check messages'];
  final List<String> c = combined ?? <String>[...p1, ...p2];

  // Auto-derive items with stable IDs from combined unless caller overrides.
  const List<String> idPool = <String>[
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
  ];
  final List<Map<String, dynamic>> effectiveItems = items ??
      c.asMap().entries.map((MapEntry<int, String> e) {
        return <String, dynamic>{
          'id': idPool[e.key % idPool.length],
          'text': e.value,
        };
      }).toList();
  final List<String> effectiveCorrectOrder = correctOrder ??
      c.asMap().entries
          .map(
            (MapEntry<int, String> e) => idPool[e.key % idPool.length],
          )
          .toList();

  return SessionPromptDto(
    orderIndex: orderIndex,
    promptId: promptId,
    contentJson: <String, dynamic>{
      'sequenceId': 'morning_routine_01',
      'theme': 'daily_routine',
      'memoryHint': 'Picture each action as it happens in order.',
      'partOne': p1,
      'partTwo': p2,
      'combined': c,
      'items': effectiveItems,
    },
    answerJson: <String, dynamic>{
      'correctOrder': effectiveCorrectOrder,
    },
    difficulty: difficulty,
    difficultyTag: difficultyTag,
    ruleType: ruleType,
    skillTags: const <String>['working_memory', 'sequencing'],
    explanation: explanation,
  );
}

SubmitGameResultRequest _request() {
  return const SubmitGameResultRequest(
    score: 400,
    accuracy: 0.75,
    totalAttempts: 4,
    correctAnswers: 3,
    wrongAnswers: 1,
    missedAnswers: 0,
    wordsSolved: 3,
    bestCombo: 2,
    averageResponseTimeMs: 1200,
  );
}

class _FakeBackendRepository implements LexRushBackendRepository {
  _FakeBackendRepository({
    this.accessTokenAvailable = true,
    this.createError,
    this.createDelay = Duration.zero,
    List<SessionPromptDto>? prompts,
  }) : prompts = prompts ?? <SessionPromptDto>[_prompt()];

  final bool accessTokenAvailable;
  Object? createError;
  final Duration createDelay;
  final List<SessionPromptDto> prompts;
  final List<String> submittedSessionIds = <String>[];
  final List<SubmitGameResultRequest> submittedRequests =
      <SubmitGameResultRequest>[];
  int createAttempts = 0;
  int submitAttempts = 0;

  @override
  Future<CreateGameSessionResponse> createGameSession(String gameId) async {
    createAttempts += 1;
    if (createDelay > Duration.zero) await Future<void>.delayed(createDelay);
    final Object? error = createError;
    if (error != null) throw error;
    return CreateGameSessionResponse(
      sessionId: 'session-1',
      gameId: gameId,
      difficulty: 1,
      status: 'created',
      timeLimitSeconds: 120,
      contentVersion: 'v2',
      prompts: prompts,
    );
  }

  @override
  Future<SubmitGameResultResponse> submitGameResult(
    String sessionId,
    SubmitGameResultRequest request,
  ) async {
    submitAttempts += 1;
    submittedSessionIds.add(sessionId);
    submittedRequests.add(request);
    return SubmitGameResultResponse(
      resultId: 'result-$sessionId',
      sessionId: sessionId,
      gameId: BackendGameIds.sequencingMemory,
      score: request.score,
      accuracy: request.accuracy,
      xpEarned: 42,
      totalAttempts: request.totalAttempts,
      correctAnswers: request.correctAnswers,
      wrongAnswers: request.wrongAnswers,
      missedAnswers: request.missedAnswers,
      createdAt: '2026-06-06T00:00:00.000Z',
    );
  }

  @override
  Future<UserProgressResponse> getMyProgress() async {
    return const UserProgressResponse(
      userId: 'user-1',
      totalXp: 42,
      currentStreak: 1,
      longestStreak: 1,
      lastTrainingDay: '2026-06-06',
      sessionsCompleted: 1,
    );
  }

  @override
  Future<UserSkillsResponse> getMySkills() async {
    return const UserSkillsResponse(
      userId: 'user-1',
      skills: <SkillProgressDto>[],
    );
  }

  @override
  Future<UserAchievementsResponse> getMyAchievements() async {
    return const UserAchievementsResponse(
      achievements: <UserAchievementDto>[],
    );
  }

  @override
  Future<TodayResponseDto> getToday() async {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasAccessToken() async {
    return accessTokenAvailable;
  }

  @override
  void close() {}
}
