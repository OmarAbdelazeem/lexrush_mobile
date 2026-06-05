class TodayResponseDto {
  const TodayResponseDto({
    required this.userId,
    required this.trainingDate,
    required this.status,
    required this.title,
    required this.message,
    required this.recommendedGames,
    required this.completedGameIds,
    required this.totalRecommendedGames,
    required this.completedRecommendedGames,
    required this.dailyXpEarned,
    required this.currentStreak,
  });

  factory TodayResponseDto.fromJson(Map<String, dynamic> json) {
    final Object? recommendedGamesJson = json['recommendedGames'];
    final Object? completedGameIdsJson = json['completedGameIds'];
    return TodayResponseDto(
      userId: json['userId'] as String,
      trainingDate: json['trainingDate'] as String,
      status: json['status'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      recommendedGames: recommendedGamesJson is List<dynamic>
          ? recommendedGamesJson
                .whereType<Map<String, dynamic>>()
                .map(RecommendedGameDto.fromJson)
                .toList()
          : <RecommendedGameDto>[],
      completedGameIds: completedGameIdsJson is List<dynamic>
          ? completedGameIdsJson.whereType<String>().toList()
          : <String>[],
      totalRecommendedGames: json['totalRecommendedGames'] as int,
      completedRecommendedGames: json['completedRecommendedGames'] as int,
      dailyXpEarned: json['dailyXpEarned'] as int,
      currentStreak: json['currentStreak'] as int,
    );
  }

  final String userId;
  final String trainingDate;
  final String status;
  final String title;
  final String message;
  final List<RecommendedGameDto> recommendedGames;
  final List<String> completedGameIds;
  final int totalRecommendedGames;
  final int completedRecommendedGames;
  final int dailyXpEarned;
  final int currentStreak;

  bool get isCompleted => status == 'completed';
}

class RecommendedGameDto {
  const RecommendedGameDto({
    required this.gameId,
    required this.title,
    required this.skillFocus,
    required this.estimatedMinutes,
    required this.completedToday,
  });

  factory RecommendedGameDto.fromJson(Map<String, dynamic> json) {
    final Object? skillFocusJson = json['skillFocus'];
    return RecommendedGameDto(
      gameId: json['gameId'] as String,
      title: json['title'] as String,
      skillFocus: skillFocusJson is List<dynamic>
          ? skillFocusJson.whereType<String>().toList()
          : <String>[],
      estimatedMinutes: json['estimatedMinutes'] as int,
      completedToday: json['completedToday'] as bool,
    );
  }

  final String gameId;
  final String title;
  final List<String> skillFocus;
  final int estimatedMinutes;
  final bool completedToday;
}
