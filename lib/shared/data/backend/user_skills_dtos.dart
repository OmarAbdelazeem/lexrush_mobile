class UserSkillsResponse {
  const UserSkillsResponse({required this.userId, required this.skills});

  factory UserSkillsResponse.fromJson(Map<String, dynamic> json) {
    final Object? skillsJson = json['skills'];
    return UserSkillsResponse(
      userId: json['userId'] as String,
      skills: skillsJson is List<dynamic>
          ? skillsJson
                .whereType<Map<String, dynamic>>()
                .map(SkillProgressDto.fromJson)
                .toList()
          : <SkillProgressDto>[],
    );
  }

  final String userId;
  final List<SkillProgressDto> skills;
}

class SkillProgressDto {
  const SkillProgressDto({
    required this.skillId,
    required this.level,
    required this.masteryScore,
    required this.accuracy,
    required this.recentTrend,
    required this.confidence,
  });

  factory SkillProgressDto.fromJson(Map<String, dynamic> json) {
    return SkillProgressDto(
      skillId: json['skillId'] as String,
      level: json['level'] as int,
      masteryScore: (json['masteryScore'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      recentTrend: json['recentTrend'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  final String skillId;
  final int level;
  final double masteryScore;
  final double accuracy;
  final String recentTrend;
  final double confidence;
}
