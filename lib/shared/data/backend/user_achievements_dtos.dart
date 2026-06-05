class UserAchievementsResponse {
  const UserAchievementsResponse({required this.achievements});

  factory UserAchievementsResponse.fromJson(Map<String, dynamic> json) {
    final Object? achievementsJson = json['achievements'];
    return UserAchievementsResponse(
      achievements: achievementsJson is List<dynamic>
          ? achievementsJson
                .whereType<Map<String, dynamic>>()
                .map(UserAchievementDto.fromJson)
                .toList()
          : <UserAchievementDto>[],
    );
  }

  final List<UserAchievementDto> achievements;
}

class UserAchievementDto {
  const UserAchievementDto({
    required this.achievementId,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.progress,
    required this.target,
    required this.unlockedAt,
    required this.iconKey,
  });

  factory UserAchievementDto.fromJson(Map<String, dynamic> json) {
    return UserAchievementDto(
      achievementId: json['achievementId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      progress: json['progress'] as int,
      target: json['target'] as int,
      unlockedAt: json['unlockedAt'] as String?,
      iconKey: json['iconKey'] as String,
    );
  }

  final String achievementId;
  final String title;
  final String description;
  final String category;
  final String status;
  final int progress;
  final int target;
  final String? unlockedAt;
  final String iconKey;

  bool get isUnlocked => status == 'unlocked';
}
