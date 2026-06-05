import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/association/application/services/association_backend_bootstrap.dart';
import 'package:lexrush/features/games/association/data/association_prompt_snapshot_mapper.dart';
import 'package:lexrush/features/games/association/domain/entities/association_difficulty.dart';
import 'package:lexrush/features/games/association/domain/entities/association_type.dart';
import 'package:lexrush/features/games/association/domain/services/association_round_generator.dart';
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
  group('AssociationPromptSnapshotMapper', () {
    test('maps backend snapshots in order', () {
      final prompts = AssociationPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(orderIndex: 2, promptId: 'second', target: 'ocean'),
          _prompt(
            orderIndex: 1,
            promptId: 'first',
            target: 'forest',
            correctChoiceId: 'tree',
            choices: <Map<String, dynamic>>[
              <String, dynamic>{'id': 'fire', 'text': 'flame'},
              <String, dynamic>{'id': 'tree', 'text': 'tree'},
            ],
            contextHint: 'nature',
            difficulty: 2,
            difficultyTag: 'medium',
            explanation: 'A forest is full of trees.',
          ),
        ],
      );

      expect(prompts.map((prompt) => prompt.targetWord), <String>[
        'forest',
        'ocean',
      ]);
      expect(prompts.first.correctAnswer, 'tree');
      expect(prompts.first.wrongAnswer, 'flame');
      expect(prompts.first.correctChoiceId, 'tree');
      expect(prompts.first.wrongChoiceId, 'fire');
      expect(prompts.first.contextHint, 'nature');
      expect(prompts.first.explanation, 'A forest is full of trees.');
      expect(prompts.first.difficulty, AssociationDifficulty.medium);
      expect(prompts.first.type, AssociationType.meaningMatch);
    });

    test('skips invalid snapshots', () {
      final prompts = AssociationPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(target: ''),
          _prompt(explanation: ''),
          _prompt(correctChoiceId: 'missing'),
          _prompt(
            choices: <Map<String, dynamic>>[
              <String, dynamic>{'id': 'a', 'text': 'wave'},
            ],
          ),
          _prompt(
            choices: <Map<String, dynamic>>[
              <String, dynamic>{'id': '', 'text': 'wave'},
              <String, dynamic>{'id': 'b', 'text': 'flame'},
            ],
          ),
        ],
      );

      expect(prompts, isEmpty);
    });

    test(
      'duplicate display text does not confuse backend choice id correctness',
      () {
        final prompts = AssociationPromptSnapshotMapper.mapSessionPrompts(
          <SessionPromptDto>[
            _prompt(
              target: 'bank',
              correctChoiceId: 'river-bank',
              choices: <Map<String, dynamic>>[
                <String, dynamic>{'id': 'money-bank', 'text': 'bank'},
                <String, dynamic>{'id': 'river-bank', 'text': 'bank'},
              ],
            ),
          ],
        );
        final AssociationRoundGenerator generator = AssociationRoundGenerator(
          prompts: prompts,
          preservePromptOrder: true,
        );

        final round = generator.generate(secondsLeft: 60, wordsSolved: 0);

        expect(round.options, hasLength(2));
        expect(
          round.options
              .singleWhere((option) => option.id == 'river-bank')
              .isCorrect,
          isTrue,
        );
        expect(
          round.options
              .singleWhere((option) => option.id == 'money-bank')
              .isCorrect,
          isFalse,
        );
      },
    );
  });

  group('AssociationBackendBootstrap', () {
    test(
      'logged out uses local prompts and does not create backend session',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository(
          accessTokenAvailable: false,
        );

        final result = await AssociationBackendBootstrap(
          repository: repository,
        ).load();

        expect(result.usedBackendPrompts, isFalse);
        expect(result.syncService, isNull);
        expect(result.createResultSyncOnFinish, isFalse);
        expect(result.fallbackSyncStatus?.phase, BackendSyncPhase.authRequired);
        expect(repository.createAttempts, 0);
      },
    );

    test('session creation failure allows result-time sync attempt', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository(
        createError: Exception('offline'),
      );

      final result = await AssociationBackendBootstrap(
        repository: repository,
      ).load();
      repository.createError = null;

      final resultTimeSync = BackendResultSyncService(
        gameId: BackendGameIds.association,
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
    });

    test('slow session creation falls back locally for gameplay', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository(
        createDelay: const Duration(milliseconds: 50),
      );

      final result = await AssociationBackendBootstrap(
        repository: repository,
        timeout: const Duration(milliseconds: 10),
      ).load();

      expect(result.usedBackendPrompts, isFalse);
      expect(result.createResultSyncOnFinish, isTrue);
      expect(result.fallbackSyncStatus, isNull);
    });

    test(
      'invalid backend prompt session is not reused for result sync',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository(
          prompts: <SessionPromptDto>[_prompt(explanation: '')],
        );

        final result = await AssociationBackendBootstrap(
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

        final result = await AssociationBackendBootstrap(
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

    test('backend generator preserves order and recycles prompts', () {
      final prompts = AssociationPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(orderIndex: 1, target: 'first'),
          _prompt(orderIndex: 2, target: 'second'),
        ],
      );
      final generator = AssociationRoundGenerator(
        prompts: prompts,
        preservePromptOrder: true,
      );

      final first = generator.generate(secondsLeft: 60, wordsSolved: 0);
      final second = generator.generate(secondsLeft: 55, wordsSolved: 1);
      final recycled = generator.generate(secondsLeft: 50, wordsSolved: 2);

      expect(first.targetWord, 'first');
      expect(second.targetWord, 'second');
      expect(recycled.targetWord, 'first');
    });
  });
}

SessionPromptDto _prompt({
  int orderIndex = 0,
  String promptId = 'prompt-1',
  String target = 'ocean',
  String correctChoiceId = 'a',
  List<Map<String, dynamic>>? choices,
  String? contextHint,
  int difficulty = 1,
  String difficultyTag = 'beginner',
  String? ruleType = 'semantic_association',
  String? explanation = 'Waves are formed on the surface of the ocean.',
}) {
  return SessionPromptDto(
    orderIndex: orderIndex,
    promptId: promptId,
    contentJson: <String, dynamic>{
      'target': target,
      'choices':
          choices ??
          <Map<String, dynamic>>[
            <String, dynamic>{'id': 'a', 'text': 'wave'},
            <String, dynamic>{'id': 'b', 'text': 'flame'},
          ],
      'contextHint': contextHint,
      'category': 'nature',
    },
    answerJson: <String, dynamic>{'correctChoiceId': correctChoiceId},
    difficulty: difficulty,
    difficultyTag: difficultyTag,
    ruleType: ruleType,
    skillTags: const <String>['semantic_reasoning', 'vocabulary'],
    explanation: explanation,
  );
}

SubmitGameResultRequest _request() {
  return const SubmitGameResultRequest(
    score: 200,
    accuracy: 1,
    totalAttempts: 1,
    correctAnswers: 1,
    wrongAnswers: 0,
    missedAnswers: 0,
    wordsSolved: 1,
    bestCombo: 1,
    averageResponseTimeMs: 900,
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
      timeLimitSeconds: 60,
      contentVersion: 'v1',
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
    return SubmitGameResultResponse(
      resultId: 'result-$sessionId',
      sessionId: sessionId,
      gameId: BackendGameIds.association,
      score: request.score,
      accuracy: request.accuracy,
      xpEarned: 42,
      totalAttempts: request.totalAttempts,
      correctAnswers: request.correctAnswers,
      wrongAnswers: request.wrongAnswers,
      missedAnswers: request.missedAnswers,
      createdAt: '2026-06-01T00:00:00.000Z',
    );
  }

  @override
  Future<UserProgressResponse> getMyProgress() async {
    return const UserProgressResponse(
      userId: 'user-1',
      totalXp: 42,
      currentStreak: 1,
      longestStreak: 1,
      lastTrainingDay: '2026-06-01',
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
    return const UserAchievementsResponse(achievements: <UserAchievementDto>[]);
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
