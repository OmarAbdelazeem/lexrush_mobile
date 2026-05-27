import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexrush/core/network/api_auth_headers_provider.dart';
import 'package:lexrush/core/network/api_client.dart';
import 'package:lexrush/core/network/api_config.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/features/games/commas/application/services/commas_backend_sync_service.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_round_result.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
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
              },
            ],
          });

      expect(response.sessionId, 'session-1');
      expect(response.prompts.single.promptId, 'prompt-1');
      expect(response.prompts.single.contentJson['text'], 'Hello world');
      expect(response.prompts.single.skillTags, contains('punctuation'));
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
  });

  group('ApiClient and repository', () {
    test(
      'sends centralized dev-user header and maps repository calls',
      () async {
        final List<http.Request> requests = <http.Request>[];
        final ApiClient client = ApiClient(
          config: const ApiConfig(baseUrl: 'http://example.test'),
          authHeadersProvider: ApiAuthHeadersProvider.dev(),
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

        expect(
          requests.every(
            (http.Request request) =>
                request.headers['x-dev-user-id'] == 'dev-user-001',
          ),
          isTrue,
        );
      },
    );

    test('parses backend error envelopes', () async {
      final ApiClient client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://example.test'),
        authHeadersProvider: ApiAuthHeadersProvider.dev(),
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
        () => client.post('/game-sessions/session-1/results'),
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

  group('Commas result sync mapping', () {
    test('uses decimal accuracy and maps wrong taps as wrong answers', () {
      final SubmitGameResultRequest request =
          CommasBackendSyncService.buildSummaryRequest(
            const CommasGameResult(
              summary: GameResult(
                stats: GameSessionStats(
                  score: 200,
                  accuracy: 50,
                  bestCombo: 1,
                  xpEarned: 5,
                  totalAttempts: 2,
                  correctAnswers: 1,
                  wordsSolved: 1,
                  missedWords: 1,
                  averageResponseTimeMs: 3000,
                ),
                replayGoal: ReplayGoal('Again'),
              ),
              review: <CommaRoundResult>[],
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
}
