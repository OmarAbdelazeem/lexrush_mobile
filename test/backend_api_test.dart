import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/auth/token_store.dart';
import 'package:lexrush/core/network/api_auth_headers_provider.dart';
import 'package:lexrush/core/network/api_client.dart';
import 'package:lexrush/core/network/api_config.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/core/network/request_auth_policy.dart';
import 'package:lexrush/features/games/association/domain/entities/association_game_result.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round_result.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_round_result.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_game_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_round_result.dart';
import 'package:lexrush/shared/application/services/backend_result_mappers.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/today_dtos.dart';
import 'package:lexrush/shared/data/backend/user_achievements_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';
import 'package:lexrush/shared/domain/entities/replay_goal.dart';

void main() {
  group('Backend DTOs', () {
    test('maps create session response with prompts', () {
      final CreateGameSessionResponse response =
          CreateGameSessionResponse.fromJson(<String, dynamic>{
            'sessionId': 'session-1',
            'gameId': 'commas',
            'difficulty': 1,
            'status': 'created',
            'timeLimitSeconds': 60,
            'contentVersion': 'v1',
            'prompts': <Map<String, dynamic>>[
              <String, dynamic>{
                'orderIndex': 0,
                'promptId': 'prompt-1',
                'contentJson': <String, dynamic>{'text': 'Hello world'},
                'answerJson': <String, dynamic>{
                  'insertionPoints': <int>[1],
                },
                'difficulty': 1,
                'difficultyTag': 'easy',
                'ruleType': 'location',
                'skillTags': <String>['grammar', 'punctuation'],
                'explanation': 'Use a comma between a city and country.',
              },
            ],
          });

      expect(response.sessionId, 'session-1');
      expect(response.prompts.single.promptId, 'prompt-1');
      expect(response.prompts.single.contentJson['text'], 'Hello world');
      expect(response.prompts.single.skillTags, contains('punctuation'));
      expect(
        response.prompts.single.explanation,
        'Use a comma between a city and country.',
      );
    });

    test('maps result, progress, and skills responses', () {
      final SubmitGameResultResponse result =
          SubmitGameResultResponse.fromJson(<String, dynamic>{
            'resultId': 'result-1',
            'sessionId': 'session-1',
            'gameId': 'commas',
            'score': 750,
            'accuracy': 0.8,
            'xpEarned': 37,
            'totalAttempts': 10,
            'correctAnswers': 8,
            'wrongAnswers': 2,
            'missedAnswers': 0,
            'createdAt': '2026-05-27T12:00:00.000Z',
          });
      final UserProgressResponse progress =
          UserProgressResponse.fromJson(<String, dynamic>{
            'userId': 'dev-user-001',
            'totalXp': 37,
            'currentStreak': 1,
            'longestStreak': 1,
            'lastTrainingDay': null,
            'sessionsCompleted': 1,
          });
      final UserSkillsResponse emptySkills = UserSkillsResponse.fromJson(
        <String, dynamic>{'userId': 'dev-user-001', 'skills': <dynamic>[]},
      );
      final UserSkillsResponse skills = UserSkillsResponse.fromJson(
        <String, dynamic>{
          'userId': 'dev-user-001',
          'skills': <Map<String, dynamic>>[
            <String, dynamic>{
              'skillId': 'punctuation',
              'level': 2,
              'masteryScore': 0.24,
              'accuracy': 0.4,
              'recentTrend': 'improving',
              'confidence': 0.35,
            },
          ],
        },
      );

      expect(result.xpEarned, 37);
      expect(result.accuracy, 0.8);
      expect(progress.lastTrainingDay, isNull);
      expect(emptySkills.skills, isEmpty);
      expect(skills.skills.single.skillId, 'punctuation');
    });

    test('maps achievements response preserving backend order', () {
      final UserAchievementsResponse response =
          UserAchievementsResponse.fromJson(<String, dynamic>{
            'achievements': <Map<String, dynamic>>[
              <String, dynamic>{
                'achievementId': 'first_step',
                'title': 'First Step',
                'description': 'Complete your first session',
                'category': 'milestone',
                'status': 'unlocked',
                'progress': 1,
                'target': 1,
                'unlockedAt': '2026-06-01T12:00:00.000Z',
                'iconKey': 'achievement_first_step',
              },
              <String, dynamic>{
                'achievementId': 'getting_warmed_up',
                'title': 'Getting Warmed Up',
                'description': 'Complete five sessions',
                'category': 'milestone',
                'status': 'locked',
                'progress': 2,
                'target': 5,
                'unlockedAt': null,
                'iconKey': 'achievement_getting_warmed_up',
              },
            ],
          });

      expect(
        response.achievements.map(
          (UserAchievementDto achievement) => achievement.achievementId,
        ),
        <String>['first_step', 'getting_warmed_up'],
      );
      expect(response.achievements.first.isUnlocked, isTrue);
      expect(response.achievements.first.unlockedAt, isNotNull);
      expect(response.achievements.last.isUnlocked, isFalse);
      expect(response.achievements.last.progress, 2);
      expect(response.achievements.last.target, 5);
    });

    test('maps today response preserving recommended game order', () {
      final TodayResponseDto response = TodayResponseDto.fromJson(
        <String, dynamic>{
          'userId': 'user-1',
          'trainingDate': '2026-06-05',
          'status': 'in_progress',
          'title': 'Keep Going!',
          'message': "1 of 2 games done — you're on a roll!",
          'recommendedGames': <Map<String, dynamic>>[
            <String, dynamic>{
              'gameId': 'commas',
              'title': 'Commas',
              'skillFocus': <String>['grammar', 'punctuation', 'precision'],
              'estimatedMinutes': 2,
              'completedToday': true,
            },
            <String, dynamic>{
              'gameId': 'antonym_rush',
              'title': 'Antonym Rush',
              'skillFocus': <String>[
                'vocabulary',
                'processing_speed',
                'attention',
              ],
              'estimatedMinutes': 2,
              'completedToday': false,
            },
          ],
          'completedGameIds': <String>['commas'],
          'totalRecommendedGames': 2,
          'completedRecommendedGames': 1,
          'dailyXpEarned': 53,
          'currentStreak': 2,
        },
      );

      expect(response.userId, 'user-1');
      expect(response.status, 'in_progress');
      expect(response.isCompleted, isFalse);
      expect(response.completedGameIds, <String>['commas']);
      expect(
        response.recommendedGames.map((RecommendedGameDto game) => game.gameId),
        <String>['commas', 'antonym_rush'],
      );
      expect(response.recommendedGames.first.completedToday, isTrue);
      expect(response.recommendedGames.last.skillFocus, contains('attention'));
      expect(response.dailyXpEarned, 53);
      expect(response.currentStreak, 2);
    });
  });

  group('ApiClient and repository', () {
    test('sends centralized bearer auth and maps repository calls', () async {
      final _FakeTokenStore tokenStore = _FakeTokenStore(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      final List<http.Request> requests = <http.Request>[];
      final ApiClient client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://example.test'),
        tokenStore: tokenStore,
        authHeadersProvider: ApiAuthHeadersProvider(tokenStore: tokenStore),
        httpClient: MockClient((http.Request request) async {
          requests.add(request);
          if (request.url.path == '/game-sessions') {
            expect(jsonDecode(request.body), <String, dynamic>{
              'gameId': 'commas',
            });
            return http.Response(
              jsonEncode(<String, dynamic>{
                'sessionId': 'session-1',
                'gameId': 'commas',
                'difficulty': 1,
                'status': 'created',
                'timeLimitSeconds': 60,
                'contentVersion': 'v1',
                'prompts': <dynamic>[],
              }),
              201,
            );
          }
          if (request.url.path == '/game-sessions/session-1/results') {
            final Map<String, dynamic> body =
                jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['accuracy'], 0.5);
            expect(body.containsKey('answerEvents'), isFalse);
            return http.Response(
              jsonEncode(<String, dynamic>{
                'resultId': 'result-1',
                'sessionId': 'session-1',
                'gameId': 'commas',
                'score': 200,
                'accuracy': 0.5,
                'xpEarned': 22,
                'totalAttempts': 2,
                'correctAnswers': 1,
                'wrongAnswers': 1,
                'missedAnswers': 0,
                'createdAt': '2026-05-27T12:00:00.000Z',
              }),
              201,
            );
          }
          if (request.url.path == '/me/progress') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'userId': 'dev-user-001',
                'totalXp': 22,
                'currentStreak': 1,
                'longestStreak': 1,
                'lastTrainingDay': '2026-05-27',
                'sessionsCompleted': 1,
              }),
              200,
            );
          }
          if (request.url.path == '/me/skills') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'userId': 'dev-user-001',
                'skills': <dynamic>[],
              }),
              200,
            );
          }
          if (request.url.path == '/me/achievements') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'achievements': <dynamic>[
                  <String, dynamic>{
                    'achievementId': 'first_step',
                    'title': 'First Step',
                    'description': 'Complete your first session',
                    'category': 'milestone',
                    'status': 'unlocked',
                    'progress': 1,
                    'target': 1,
                    'unlockedAt': '2026-06-01T12:00:00.000Z',
                    'iconKey': 'achievement_first_step',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/me/today') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'userId': 'dev-user-001',
                'trainingDate': '2026-06-05',
                'status': 'in_progress',
                'title': 'Keep Going!',
                'message': "1 of 2 games done — you're on a roll!",
                'recommendedGames': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'gameId': 'commas',
                    'title': 'Commas',
                    'skillFocus': <String>[
                      'grammar',
                      'punctuation',
                      'precision',
                    ],
                    'estimatedMinutes': 2,
                    'completedToday': true,
                  },
                ],
                'completedGameIds': <String>['commas'],
                'totalRecommendedGames': 2,
                'completedRecommendedGames': 1,
                'dailyXpEarned': 53,
                'currentStreak': 2,
              }),
              200,
              headers: _jsonHeaders,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      final LexRushBackendRepository repository = LexRushBackendRepository(
        apiClient: client,
      );

      final CreateGameSessionResponse session = await repository
          .createGameSession('commas');
      await repository.submitGameResult(
        session.sessionId,
        const SubmitGameResultRequest(
          score: 200,
          accuracy: 0.5,
          totalAttempts: 2,
          correctAnswers: 1,
          wrongAnswers: 1,
          missedAnswers: 0,
          wordsSolved: 1,
          bestCombo: 1,
          averageResponseTimeMs: 3000,
        ),
      );
      await repository.getMyProgress();
      await repository.getMySkills();
      final UserAchievementsResponse achievements = await repository
          .getMyAchievements();
      final TodayResponseDto today = await repository.getToday();

      expect(
        requests.every(
          (http.Request request) =>
              request.headers['Authorization'] == 'Bearer access-1',
        ),
        isTrue,
      );
      expect(achievements.achievements.single.achievementId, 'first_step');
      expect(
        requests.map((http.Request request) => request.url.path),
        contains('/me/achievements'),
      );
      expect(today.recommendedGames.single.gameId, 'commas');
      expect(
        requests.map((http.Request request) => request.url.path),
        contains('/me/today'),
      );
    });

    test('parses backend error envelopes', () async {
      final _FakeTokenStore tokenStore = _FakeTokenStore();
      final ApiClient client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://example.test'),
        tokenStore: tokenStore,
        authHeadersProvider: ApiAuthHeadersProvider(tokenStore: tokenStore),
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'error': <String, dynamic>{
                'code': 'SESSION_ALREADY_COMPLETED',
                'message': 'Session already completed.',
              },
            }),
            409,
          );
        }),
      );

      expect(
        () => client.post(
          '/game-sessions/session-1/results',
          authPolicy: RequestAuthPolicy.public,
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'statusCode', 409)
              .having(
                (ApiException e) => e.code,
                'code',
                'SESSION_ALREADY_COMPLETED',
              )
              .having(
                (ApiException e) => e.isSessionAlreadyCompleted,
                'isSessionAlreadyCompleted',
                isTrue,
              ),
        ),
      );
    });
  });

  group('Backend result mappings', () {
    test('maps Antonym Rush summary fields', () {
      final SubmitGameResultRequest request = BackendResultMappers.antonymRush(
        _gameResult(
          score: 500,
          accuracy: 80,
          totalAttempts: 10,
          correctAnswers: 8,
          missedWords: 1,
          wordsSolved: 8,
          bestCombo: 4,
          averageResponseTimeMs: 1200,
        ),
      );

      expect(request.toJson(), <String, dynamic>{
        'score': 500,
        'accuracy': 0.8,
        'totalAttempts': 10,
        'correctAnswers': 8,
        'wrongAnswers': 1,
        'missedAnswers': 1,
        'wordsSolved': 8,
        'bestCombo': 4,
        'averageResponseTimeMs': 1200,
      });
    });

    test('maps Association summary fields', () {
      final SubmitGameResultRequest request = BackendResultMappers.association(
        AssociationGameResult(
          summary: _gameResult(
            score: 700,
            accuracy: 70,
            totalAttempts: 10,
            correctAnswers: 7,
            missedWords: 2,
            wordsSolved: 7,
            bestCombo: 3,
            averageResponseTimeMs: 1500,
          ),
          review: const <AssociationRoundResult>[],
        ),
      );

      expect(request.toJson(), <String, dynamic>{
        'score': 700,
        'accuracy': 0.7,
        'totalAttempts': 10,
        'correctAnswers': 7,
        'wrongAnswers': 1,
        'missedAnswers': 2,
        'wordsSolved': 7,
        'bestCombo': 3,
        'averageResponseTimeMs': 1500,
      });
    });

    test('maps Sequencing Memory routes and stage stats', () {
      final SubmitGameResultRequest request =
          BackendResultMappers.sequencingMemory(
            SequencingGameResult(
              summary: _gameResult(
                score: 360,
                accuracy: 90,
                totalAttempts: 9,
                correctAnswers: 6,
                missedWords: 3,
                wordsSolved: 6,
                bestCombo: 6,
                averageResponseTimeMs: 4200,
              ),
              review: const <SequencingRoundResult>[],
              sequencesCompleted: 3,
              perfectStages: 6,
              longestSequenceRemembered: 5,
              replayCount: 1,
              averageRecallTimeMs: 4200,
            ),
          );

      expect(request.toJson(), <String, dynamic>{
        'score': 360,
        'accuracy': 0.9,
        'totalAttempts': 9,
        'correctAnswers': 6,
        'wrongAnswers': 3,
        'missedAnswers': 0,
        'wordsSolved': 3,
        'bestCombo': 6,
        'averageResponseTimeMs': 4200,
      });
    });

    test('maps Commas wrong taps as wrong answers', () {
      final SubmitGameResultRequest request = BackendResultMappers.commas(
        CommasGameResult(
          summary: _gameResult(
            score: 200,
            accuracy: 50,
            totalAttempts: 2,
            correctAnswers: 1,
            missedWords: 1,
            wordsSolved: 1,
            bestCombo: 1,
            averageResponseTimeMs: 3000,
          ),
          review: const <CommaRoundResult>[],
        ),
      );

      expect(request.toJson(), <String, dynamic>{
        'score': 200,
        'accuracy': 0.5,
        'totalAttempts': 2,
        'correctAnswers': 1,
        'wrongAnswers': 1,
        'missedAnswers': 0,
        'wordsSolved': 1,
        'bestCombo': 1,
        'averageResponseTimeMs': 3000,
      });
    });
  });

  group('ApiException.isRateLimited', () {
    test('true for RATE_LIMITED code with 429 status', () {
      const ApiException e = ApiException(
        statusCode: 429,
        code: 'RATE_LIMITED',
        message: 'Too many requests.',
      );
      expect(e.isRateLimited, isTrue);
    });

    test('true for 429 status even without code', () {
      const ApiException e = ApiException(
        statusCode: 429,
        message: 'Too many requests.',
      );
      expect(e.isRateLimited, isTrue);
    });

    test('true for RATE_LIMITED code even without 429 status', () {
      const ApiException e = ApiException(
        statusCode: 200,
        code: 'RATE_LIMITED',
        message: 'Too many requests.',
      );
      expect(e.isRateLimited, isTrue);
    });

    test('false for non-rate-limit errors', () {
      const ApiException unauthorized = ApiException(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Not authorized.',
      );
      const ApiException invalidRefresh = ApiException(
        statusCode: 401,
        code: 'INVALID_REFRESH_TOKEN',
        message: 'Token invalid.',
      );
      const ApiException sessionCompleted = ApiException(
        statusCode: 409,
        code: 'SESSION_ALREADY_COMPLETED',
        message: 'Already done.',
      );
      expect(unauthorized.isRateLimited, isFalse);
      expect(invalidRefresh.isRateLimited, isFalse);
      expect(sessionCompleted.isRateLimited, isFalse);
    });

    test('is disjoint from isInvalidRefreshToken', () {
      const ApiException rateLimited = ApiException(
        statusCode: 429,
        code: 'RATE_LIMITED',
        message: 'Too many requests.',
      );
      expect(rateLimited.isRateLimited, isTrue);
      expect(rateLimited.isInvalidRefreshToken, isFalse);
    });
  });
}

const Map<String, String> _jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

class _FakeTokenStore implements TokenStore {
  _FakeTokenStore([this.tokens]);

  AuthTokens? tokens;

  @override
  Future<void> clearTokens() async {
    tokens = null;
  }

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    this.tokens = tokens;
  }
}

GameResult _gameResult({
  required int score,
  required int accuracy,
  required int totalAttempts,
  required int correctAnswers,
  required int missedWords,
  required int wordsSolved,
  required int bestCombo,
  required int averageResponseTimeMs,
}) {
  return GameResult(
    stats: GameSessionStats(
      score: score,
      accuracy: accuracy,
      bestCombo: bestCombo,
      xpEarned: 0,
      totalAttempts: totalAttempts,
      correctAnswers: correctAnswers,
      wordsSolved: wordsSolved,
      missedWords: missedWords,
      averageResponseTimeMs: averageResponseTimeMs,
    ),
    replayGoal: const ReplayGoal('Again'),
  );
}
