import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/commas/application/services/commas_backend_bootstrap.dart';
import 'package:lexrush/features/games/commas/data/comma_prompt_snapshot_mapper.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_rule_type.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

void main() {
  group('CommaPromptSnapshotMapper', () {
    test('uses backend correctTextWithCommas when available', () {
      final prompts = CommaPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            contentJson: <String, dynamic>{
              'displayTextWithoutCommas': 'We met in Paris France yesterday.',
              'correctTextWithCommas': 'We met in Paris, France, yesterday.',
            },
            answerJson: <String, dynamic>{
              'insertionPoints': <Map<String, dynamic>>[
                <String, dynamic>{'afterTokenIndex': 3},
                <String, dynamic>{'afterTokenIndex': 4},
              ],
            },
          ),
        ],
      );

      expect(
        prompts.single.correctTextWithCommas,
        'We met in Paris, France, yesterday.',
      );
      expect(
        prompts.single.insertionPoints.map((point) => point.afterTokenIndex),
        <int>[3, 4],
      );
    });

    test('derives correct text only when backend correct text is blank', () {
      final prompts = CommaPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            contentJson: <String, dynamic>{
              'displayTextWithoutCommas': 'After lunch we left.',
              'correctTextWithCommas': ' ',
            },
            answerJson: <String, dynamic>{
              'insertionPoints': <int>[1],
            },
          ),
        ],
      );

      expect(prompts.single.correctTextWithCommas, 'After lunch, we left.');
    });

    test(
      'maps explanation, ordering, difficulty, and unknown rule fallback',
      () {
        final prompts =
            CommaPromptSnapshotMapper.mapSessionPrompts(<SessionPromptDto>[
              _prompt(
                orderIndex: 2,
                promptId: 'second',
                difficulty: 3,
                difficultyTag: 'hard',
                ruleType: 'mystery',
                explanation: 'Backend explanation.',
              ),
              _prompt(
                orderIndex: 1,
                promptId: 'first',
                difficulty: 2,
                difficultyTag: 'medium',
                ruleType: 'location',
              ),
            ]);

        expect(prompts.map((prompt) => prompt.id), <String>['first', 'second']);
        expect(prompts.first.difficulty, CommaDifficulty.medium);
        expect(prompts.first.ruleType, CommaRuleType.location);
        expect(prompts.last.difficulty, CommaDifficulty.hard);
        expect(prompts.last.ruleType, CommaRuleType.general);
        expect(prompts.last.explanation, 'Backend explanation.');
      },
    );

    test('skips invalid snapshots', () {
      final prompts = CommaPromptSnapshotMapper.mapSessionPrompts(
        <SessionPromptDto>[
          _prompt(
            contentJson: <String, dynamic>{
              'displayTextWithoutCommas': 'No gap here.',
            },
            answerJson: <String, dynamic>{
              'insertionPoints': <Map<String, dynamic>>[
                <String, dynamic>{'afterTokenIndex': 9},
              ],
            },
          ),
        ],
      );

      expect(prompts, isEmpty);
    });
  });

  group('CommasBackendBootstrap', () {
    test(
      'logged out uses local prompts and exposes auth-required status',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository(
          accessTokenAvailable: false,
        );

        final result = await CommasBackendBootstrap(
          repository: repository,
        ).load();

        expect(result.usedBackendPrompts, isFalse);
        expect(result.syncService, isNull);
        expect(result.fallbackSyncStatus?.phase, BackendSyncPhase.authRequired);
        expect(repository.createAttempts, 0);
      },
    );

    test('backend failure uses local prompts', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository(
        createError: Exception('offline'),
      );

      final result = await CommasBackendBootstrap(
        repository: repository,
      ).load();

      expect(result.usedBackendPrompts, isFalse);
      expect(result.syncService, isNull);
      expect(result.fallbackSyncStatus?.phase, BackendSyncPhase.failed);
      expect(repository.createAttempts, 1);
    });

    test('slow backend times out and uses local prompts', () async {
      final _FakeBackendRepository repository = _FakeBackendRepository(
        createDelay: const Duration(milliseconds: 50),
      );

      final result = await CommasBackendBootstrap(
        repository: repository,
        timeout: const Duration(milliseconds: 10),
      ).load();

      expect(result.usedBackendPrompts, isFalse);
      expect(result.syncService, isNull);
      expect(result.fallbackSyncStatus?.phase, BackendSyncPhase.failed);
    });

    test(
      'invalid backend prompt session is not reused for result sync',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository(
          prompts: <SessionPromptDto>[
            _prompt(
              answerJson: <String, dynamic>{
                'insertionPoints': <Map<String, dynamic>>[
                  <String, dynamic>{'afterTokenIndex': 99},
                ],
              },
            ),
          ],
        );

        final result = await CommasBackendBootstrap(
          repository: repository,
        ).load();

        expect(result.usedBackendPrompts, isFalse);
        expect(result.syncService, isNull);
        expect(repository.createAttempts, 1);
        expect(repository.submitAttempts, 0);
      },
    );

    test(
      'valid backend prompt session is reused for result submission',
      () async {
        final _FakeBackendRepository repository = _FakeBackendRepository();

        final result = await CommasBackendBootstrap(
          repository: repository,
        ).load();
        final handle = result.syncService!.submitSummaryWithHandle(_request());
        await handle.completed;

        expect(result.usedBackendPrompts, isTrue);
        expect(repository.createAttempts, 1);
        expect(repository.submitAttempts, 1);
        expect(handle.statusListenable.value.phase, BackendSyncPhase.synced);
        handle.dispose();
      },
    );
  });
}

SessionPromptDto _prompt({
  int orderIndex = 0,
  String promptId = 'prompt-1',
  Map<String, dynamic>? contentJson,
  Map<String, dynamic>? answerJson,
  int difficulty = 1,
  String difficultyTag = 'easy',
  String? ruleType = 'location',
  String? explanation,
}) {
  return SessionPromptDto(
    orderIndex: orderIndex,
    promptId: promptId,
    contentJson:
        contentJson ??
        <String, dynamic>{
          'displayTextWithoutCommas': 'After lunch we left.',
          'correctTextWithCommas': 'After lunch, we left.',
        },
    answerJson:
        answerJson ??
        <String, dynamic>{
          'insertionPoints': <Map<String, dynamic>>[
            <String, dynamic>{'afterTokenIndex': 1},
          ],
        },
    difficulty: difficulty,
    difficultyTag: difficultyTag,
    ruleType: ruleType,
    skillTags: const <String>['punctuation'],
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
  final Object? createError;
  final Duration createDelay;
  final List<SessionPromptDto> prompts;
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
    return const SubmitGameResultResponse(
      resultId: 'result-1',
      sessionId: 'session-1',
      gameId: 'commas',
      score: 200,
      accuracy: 1,
      xpEarned: 42,
      totalAttempts: 1,
      correctAnswers: 1,
      wrongAnswers: 0,
      missedAnswers: 0,
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
  Future<bool> hasAccessToken() async => accessTokenAvailable;

  @override
  void close() {}
}
