import 'package:lexrush/core/network/api_client.dart';
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
    );
    return SubmitGameResultResponse.fromJson(json);
  }

  Future<UserProgressResponse> getMyProgress() async {
    final Map<String, dynamic> json = await _apiClient.get('/me/progress');
    return UserProgressResponse.fromJson(json);
  }

  Future<UserSkillsResponse> getMySkills() async {
    final Map<String, dynamic> json = await _apiClient.get('/me/skills');
    return UserSkillsResponse.fromJson(json);
  }

  void close() => _apiClient.close();
}
