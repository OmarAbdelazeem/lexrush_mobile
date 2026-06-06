import 'package:lexrush/shared/domain/contracts/analytics_port.dart';
import 'package:lexrush/shared/domain/contracts/audio_feedback_port.dart';
import 'package:lexrush/shared/domain/contracts/crash_reporter.dart';
import 'package:lexrush/shared/domain/contracts/haptics_port.dart';

class NoopAnalyticsPort implements AnalyticsPort {
  @override
  Future<void> trackAppStarted() async {}

  @override
  Future<void> trackAuthLoginSuccess({required String userId}) async {}

  @override
  Future<void> trackAuthRegisterSuccess({required String userId}) async {}

  @override
  Future<void> trackAuthLogout() async {}

  @override
  Future<void> trackGameStarted({
    required String gameId,
    required String source,
    required bool usedBackendPrompts,
  }) async {}

  @override
  Future<void> trackGameCompleted({
    required String gameId,
    required int score,
    required double accuracy,
    required int durationSeconds,
    required bool usedBackendPrompts,
  }) async {}

  @override
  Future<void> trackResultSyncStatus({
    required String gameId,
    required String status,
    int? xpEarned,
  }) async {}

  @override
  Future<void> trackBackendPromptBootstrap({
    required String gameId,
    required String outcome,
  }) async {}

  @override
  Future<void> trackOfflineRetryDrain({
    required int startedCount,
    required int succeededCount,
    required int failedCount,
    int? removedDuplicateCount,
  }) async {}

  @override
  Future<void> trackTodayLoaded({
    required String status,
    required int completedRecommendedGames,
    required int totalRecommendedGames,
  }) async {}

  @override
  Future<void> trackProfileLoaded({
    required int achievementsCount,
    required int unlockedAchievementsCount,
  }) async {}

  @override
  Future<void> trackTtsFailsafeTriggered({
    required String stage,
    required int itemCount,
    required String reason,
  }) async {}
}

class NoopCrashReporter implements CrashReporter {
  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? context,
  }) async {}

  @override
  void setUserId(String? userId) {}
}

class NoopAudioFeedbackPort implements AudioFeedbackPort {
  @override
  Future<void> playError() async {}

  @override
  Future<void> playMissed() async {}

  @override
  Future<void> playSuccess() async {}
}

class NoopHapticsPort implements HapticsPort {
  @override
  Future<void> heavyImpact() async {}

  @override
  Future<void> lightImpact() async {}
}
