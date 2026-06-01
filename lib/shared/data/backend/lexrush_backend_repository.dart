import 'package:lexrush/core/network/api_client.dart';
import 'package:lexrush/core/network/request_auth_policy.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

class LexRushBackendRepository {
  const LexRushBackendRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<CreateGameSessionResponse> createGameSession(String gameId) async {
    final Map<String, dynamic> json = await _apiClient.post(
      '/game-sessions',
      body: CreateGameSessionRequest(gameId: gameId).toJson(),
      authPolicy: RequestAuthPolicy.requiredAuth,
    );
    return CreateGameSessionResponse.fromJson(json);
  }

  Future<SubmitGameResultResponse> submitGameResult(
    String sessionId,
    SubmitGameResultRequest request,
  ) async {
    final Map<String, dynamic> json = await _apiClient.post(
      '/game-sessions/$sessionId/results',
      body: request.toJson(),
      authPolicy: RequestAuthPolicy.requiredAuth,
    );
    return SubmitGameResultResponse.fromJson(json);
  }

  Future<UserProgressResponse> getMyProgress() async {
    final Map<String, dynamic> json = await _apiClient.get(
      '/me/progress',
      authPolicy: RequestAuthPolicy.requiredAuth,
    );
    return UserProgressResponse.fromJson(json);
  }

  Future<UserSkillsResponse> getMySkills() async {
    final Map<String, dynamic> json = await _apiClient.get(
      '/me/skills',
      authPolicy: RequestAuthPolicy.requiredAuth,
    );
    return UserSkillsResponse.fromJson(json);
  }

  Future<bool> hasAccessToken() => _apiClient.hasAccessToken();

  void close() => _apiClient.close();
}
