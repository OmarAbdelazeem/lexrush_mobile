abstract class AnalyticsPort {
  Future<void> trackAppStarted();

  Future<void> trackAuthLoginSuccess({required String userId});
  Future<void> trackAuthRegisterSuccess({required String userId});
  Future<void> trackAuthLogout();

  Future<void> trackGameStarted({
    required String gameId,
    required String source,
    required bool usedBackendPrompts,
  });

  Future<void> trackGameCompleted({
    required String gameId,
    required int score,
    required double accuracy,
    required int durationSeconds,
    required bool usedBackendPrompts,
  });

  Future<void> trackResultSyncStatus({
    required String gameId,
    required String status,
    int? xpEarned,
  });

  Future<void> trackBackendPromptBootstrap({
    required String gameId,
    required String outcome,
  });

  Future<void> trackOfflineRetryDrain({
    required int startedCount,
    required int succeededCount,
    required int failedCount,
    int? removedDuplicateCount,
  });

  Future<void> trackTodayLoaded({
    required String status,
    required int completedRecommendedGames,
    required int totalRecommendedGames,
  });

  Future<void> trackProfileLoaded({
    required int achievementsCount,
    required int unlockedAchievementsCount,
  });

  Future<void> trackTtsFailsafeTriggered({
    required String stage,
    required int itemCount,
    required String reason,
  });
}
