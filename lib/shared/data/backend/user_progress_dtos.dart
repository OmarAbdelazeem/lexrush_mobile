class UserProgressResponse {
  const UserProgressResponse({
    required this.userId,
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastTrainingDay,
    required this.sessionsCompleted,
  });

  factory UserProgressResponse.fromJson(Map<String, dynamic> json) {
    return UserProgressResponse(
      userId: json['userId'] as String,
      totalXp: json['totalXp'] as int,
      currentStreak: json['currentStreak'] as int,
      longestStreak: json['longestStreak'] as int,
      lastTrainingDay: json['lastTrainingDay'] as String?,
      sessionsCompleted: json['sessionsCompleted'] as int,
    );
  }

  final String userId;
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final String? lastTrainingDay;
  final int sessionsCompleted;
}
