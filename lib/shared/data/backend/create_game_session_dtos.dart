class CreateGameSessionRequest {
  const CreateGameSessionRequest({required this.gameId});

  final String gameId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'gameId': gameId};
  }
}

class CreateGameSessionResponse {
  const CreateGameSessionResponse({
    required this.sessionId,
    required this.gameId,
    required this.difficulty,
    required this.status,
    required this.timeLimitSeconds,
    required this.contentVersion,
    required this.prompts,
  });

  factory CreateGameSessionResponse.fromJson(Map<String, dynamic> json) {
    final Object? promptsJson = json['prompts'];
    return CreateGameSessionResponse(
      sessionId: json['sessionId'] as String,
      gameId: json['gameId'] as String,
      difficulty: json['difficulty'] as int,
      status: json['status'] as String,
      timeLimitSeconds: json['timeLimitSeconds'] as int?,
      contentVersion: json['contentVersion'] as String,
      prompts: promptsJson is List<dynamic>
          ? promptsJson
                .whereType<Map<String, dynamic>>()
                .map(SessionPromptDto.fromJson)
                .toList()
          : <SessionPromptDto>[],
    );
  }

  final String sessionId;
  final String gameId;
  final int difficulty;
  final String status;
  final int? timeLimitSeconds;
  final String contentVersion;
  final List<SessionPromptDto> prompts;
}

class SessionPromptDto {
  const SessionPromptDto({
    required this.orderIndex,
    required this.promptId,
    required this.contentJson,
    required this.answerJson,
    required this.difficulty,
    required this.difficultyTag,
    required this.ruleType,
    required this.skillTags,
    required this.explanation,
  });

  factory SessionPromptDto.fromJson(Map<String, dynamic> json) {
    final Object? skillTagsJson = json['skillTags'];
    return SessionPromptDto(
      orderIndex: json['orderIndex'] as int,
      promptId: json['promptId'] as String,
      contentJson: _jsonMap(json['contentJson']),
      answerJson: _jsonMap(json['answerJson']),
      difficulty: json['difficulty'] as int,
      difficultyTag: json['difficultyTag'] as String,
      ruleType: json['ruleType'] as String?,
      skillTags: skillTagsJson is List<dynamic>
          ? skillTagsJson.whereType<String>().toList()
          : <String>[],
      explanation: json['explanation'] as String?,
    );
  }

  final int orderIndex;
  final String promptId;
  final Map<String, dynamic> contentJson;
  final Map<String, dynamic> answerJson;
  final int difficulty;
  final String difficultyTag;
  final String? ruleType;
  final List<String> skillTags;
  final String? explanation;
}

Map<String, dynamic> _jsonMap(Object? value) {
  return value is Map<String, dynamic> ? value : <String, dynamic>{};
}
