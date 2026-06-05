import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/antonym_rush/application/services/antonym_rush_backend_bootstrap.dart';
import 'package:lexrush/features/games/antonym_rush/data/antonym_prompt_snapshot_mapper.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_difficulty.dart';
import 'package:lexrush/features/games/antonym_rush/domain/services/antonym_difficulty_service.dart';
import 'package:lexrush/features/games/antonym_rush/domain/services/antonym_round_generator.dart';
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
  group('AntonymPromptSnapshotMapper', () {
    test('maps backend snapshots in order', () {
      final prompts = AntonymPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(orderIndex: 2, promptId: 'second', targetWord: 'quiet'),
          _prompt(
            orderIndex: 1,
            promptId: 'first',
            targetWord: 'ancient',
            correctChoiceId: 'modern',
            choices: <Map<String, dynamic>>[
              <String, dynamic>{'id': 'old', 'text': 'old'},
              <String, dynamic>{'id': 'modern', 'text': 'modern'},
              <String, dynamic>{'id': 'historic', 'text': 'historic'},
              <String, dynamic>{'id': 'aged', 'text': 'aged'},
            ],
            difficulty: 3,
            difficultyTag: 'medium',
            explanation: 'Modern is the opposite of ancient.',
          ),
        ],
      );

      expect(prompts.map((prompt) => prompt.word), <String>[
        'ancient',
        'quiet',
      ]);
      expect(prompts.first.antonym, 'modern');
      expect(prompts.first.distractors, <String>['old', 'historic', 'aged']);
      expect(prompts.first.backendOptions, hasLength(4));
      expect(prompts.first.backendOptions!.map((option) => option.id), <String>[
        'old',
        'modern',
        'historic',
        'aged',
      ]);
      expect(
        prompts.first.backendOptions!
            .singleWhere((option) => option.id == 'modern')
            .isCorrect,
        isTrue,
      );
      expect(prompts.first.explanation, 'Modern is the opposite of ancient.');
      expect(prompts.first.difficulty, AntonymDifficulty.medium);
    });

    test('skips invalid snapshots', () {
      final prompts = AntonymPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(targetWord: ''),
          _prompt(correctChoiceId: 'missing'),
          _prompt(
            choices: <Map<String, dynamic>>[
              <String, dynamic>{'id': 'a', 'text': 'near'},
              <String, dynamic>{'id': 'b', 'text': 'close'},
              <String, dynamic>{'id': 'c', 'text': 'beside'},
            ],
          ),
          _prompt(
            choices: <Map<String, dynamic>>[
              <String, dynamic>{'id': '', 'text': 'near'},
              <String, dynamic>{'id': 'b', 'text': 'far'},
              <String, dynamic>{'id': 'c', 'text': 'close'},
              <String, dynamic>{'id': 'd', 'text': 'beside'},
            ],
          ),
          _prompt(
            choices: <Map<String, dynamic>>[
              <String, dynamic>{'id': 'a', 'text': 'near'},
              <String, dynamic>{'id': 'b', 'text': ''},
              <String, dynamic>{'id': 'c', 'text': 'close'},
              <String, dynamic>{'id': 'd', 'text': 'beside'},
            ],
          ),
        ],
      );

      expect(prompts, isEmpty);
    });

    test(
      'duplicate display text does not confuse backend choice id correctness',
      () {
        final prompts = AntonymPromptSnapshotMapper.mapSessionPrompts(
          <SessionPromptDto>[
            _prompt(
              targetWord: 'close',
              correctChoiceId: 'distance-far',
              choices: <Map<String, dynamic>>[
                <String, dynamic>{'id': 'wrong-far', 'text': 'far'},
                <String, dynamic>{'id': 'distance-far', 'text': 'far'},
                <String, dynamic>{'id': 'near', 'text': 'near'},
                <String, dynamic>{'id': 'nearby', 'text': 'nearby'},
              ],
            ),
          ],
        );
        final AntonymRoundGenerator generator = AntonymRoundGenerator(
          pairs: prompts,
          difficultyService: const AntonymDifficultyService(),
          preservePromptOrder: true,
        );

        final round = generator.generate(timeLeft: 60, wordsSolved: 0);

        expect(round.options, hasLength(4));
        expect(
          round.options
              .singleWhere((option) => option.id == 'distance-far')
              .isCorrect,
          isTrue,
        );
        expect(
          round.options
              .singleWhere((option) => option.id == 'wrong-far')
              .isCorrect,
          isFalse,
        );
      },
    );
  });

  group('AntonymRushBackendBootstrap', () {
    test(
      'logged out uses local prompts and does not create backend session',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository(
          accessTokenAvailable: false,
        );

        final result = await AntonymRushBackendBootstrap(
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

      final result = await AntonymRushBackendBootstrap(
        repository: repository,
      ).load();
      repository.createError = null;

      final resultTimeSync = BackendResultSyncService(
        gameId: BackendGameIds.antonymRush,
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

      final result = await AntonymRushBackendBootstrap(
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
          prompts: <SessionPromptDto>[_prompt(correctChoiceId: 'missing')],
        );

        final result = await AntonymRushBackendBootstrap(
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

        final result = await AntonymRushBackendBootstrap(
          repository: repository,
        ).load();
        final handle = result.syncService!.submitSummaryWithHandle(_request());
        await handle.completed;

        expect(result.usedBackendPrompts, isTrue);
        expect(result.createResultSyncOnFinish, isFalse);
        expect(repository.createAttempts, 1);
        expect(repository.submitAttempts, 1);
        expect(repository.submittedSessionIds, <String>['session-1']);
        expect(repository.submittedRequests.single.accuracy, 0.75);
        expect(
          repository.submittedRequests.single.toJson().containsKey(
            'answerEvents',
          ),
          isFalse,
        );
        expect(handle.statusListenable.value.phase, BackendSyncPhase.synced);
        handle.dispose();
      },
    );

    test(
      'backend generator preserves order and recycles four-option prompts',
      () {
        final prompts =
            AntonymPromptSnapshotMapper.mapSessionPrompts(<SessionPromptDto>[
              _prompt(orderIndex: 1, targetWord: 'first'),
              _prompt(orderIndex: 2, targetWord: 'second'),
            ]);
        final generator = AntonymRoundGenerator(
          pairs: prompts,
          difficultyService: const AntonymDifficultyService(),
          preservePromptOrder: true,
        );

        final first = generator.generate(timeLeft: 60, wordsSolved: 0);
        final second = generator.generate(timeLeft: 55, wordsSolved: 1);
        final recycled = generator.generate(timeLeft: 50, wordsSolved: 2);

        expect(first.targetWord, 'first');
        expect(second.targetWord, 'second');
        expect(recycled.targetWord, 'first');
        expect(first.options, hasLength(4));
        expect(second.options, hasLength(4));
        expect(recycled.options, hasLength(4));
      },
    );
  });
}

SessionPromptDto _prompt({
  int orderIndex = 0,
  String promptId = 'prompt-1',
  String targetWord = 'near',
  String correctChoiceId = 'a',
  List<Map<String, dynamic>>? choices,
  int difficulty = 1,
  String difficultyTag = 'beginner',
  String? ruleType = 'antonym_choice',
  String? explanation = 'Far is the opposite of near.',
}) {
  return SessionPromptDto(
    orderIndex: orderIndex,
    promptId: promptId,
    contentJson: <String, dynamic>{
      'targetWord': targetWord,
      'choices':
          choices ??
          <Map<String, dynamic>>[
            <String, dynamic>{'id': 'a', 'text': 'far'},
            <String, dynamic>{'id': 'b', 'text': 'close'},
            <String, dynamic>{'id': 'c', 'text': 'nearby'},
            <String, dynamic>{'id': 'd', 'text': 'beside'},
          ],
      'partOfSpeech': 'adjective',
    },
    answerJson: <String, dynamic>{'correctChoiceId': correctChoiceId},
    difficulty: difficulty,
    difficultyTag: difficultyTag,
    ruleType: ruleType,
    skillTags: const <String>['vocabulary', 'antonyms'],
    explanation: explanation,
  );
}

SubmitGameResultRequest _request() {
  return const SubmitGameResultRequest(
    score: 200,
    accuracy: 0.75,
    totalAttempts: 4,
    correctAnswers: 3,
    wrongAnswers: 1,
    missedAnswers: 0,
    wordsSolved: 3,
    bestCombo: 2,
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
    submittedRequests.add(request);
    return SubmitGameResultResponse(
      resultId: 'result-$sessionId',
      sessionId: sessionId,
      gameId: BackendGameIds.antonymRush,
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
