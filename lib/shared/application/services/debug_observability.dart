import 'package:flutter/foundation.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';
import 'package:lexrush/shared/domain/contracts/crash_reporter.dart';

class DebugAnalyticsPort implements AnalyticsPort {
  @override
  Future<void> trackAppStarted() async =>
      debugPrint('[Analytics] app_started');

  @override
  Future<void> trackAuthLoginSuccess({required String userId}) async =>
      debugPrint('[Analytics] auth_login_success');

  @override
  Future<void> trackAuthRegisterSuccess({required String userId}) async =>
      debugPrint('[Analytics] auth_register_success');

  @override
  Future<void> trackAuthLogout() async =>
      debugPrint('[Analytics] auth_logout');

  @override
  Future<void> trackGameStarted({
    required String gameId,
    required String source,
    required bool usedBackendPrompts,
  }) async =>
      debugPrint(
        '[Analytics] game_started gameId=$gameId source=$source '
        'usedBackendPrompts=$usedBackendPrompts',
      );

  @override
  Future<void> trackGameCompleted({
    required String gameId,
    required int score,
    required double accuracy,
    required int durationSeconds,
    required bool usedBackendPrompts,
  }) async =>
      debugPrint(
        '[Analytics] game_completed gameId=$gameId score=$score '
        'accuracy=$accuracy durationSeconds=$durationSeconds '
        'usedBackendPrompts=$usedBackendPrompts',
      );

  @override
  Future<void> trackResultSyncStatus({
    required String gameId,
    required String status,
    int? xpEarned,
  }) async =>
      debugPrint(
        '[Analytics] result_sync_status gameId=$gameId status=$status'
        '${xpEarned != null ? ' xpEarned=$xpEarned' : ''}',
      );

  @override
  Future<void> trackBackendPromptBootstrap({
    required String gameId,
    required String outcome,
  }) async =>
      debugPrint(
        '[Analytics] backend_prompt_bootstrap gameId=$gameId outcome=$outcome',
      );

  @override
  Future<void> trackOfflineRetryDrain({
    required int startedCount,
    required int succeededCount,
    required int failedCount,
    int? removedDuplicateCount,
  }) async =>
      debugPrint(
        '[Analytics] offline_retry_drain started=$startedCount '
        'succeeded=$succeededCount failed=$failedCount'
        '${removedDuplicateCount != null ? ' duplicates=$removedDuplicateCount' : ''}',
      );

  @override
  Future<void> trackTodayLoaded({
    required String status,
    required int completedRecommendedGames,
    required int totalRecommendedGames,
  }) async =>
      debugPrint(
        '[Analytics] today_loaded status=$status '
        'completed=$completedRecommendedGames total=$totalRecommendedGames',
      );

  @override
  Future<void> trackProfileLoaded({
    required int achievementsCount,
    required int unlockedAchievementsCount,
  }) async =>
      debugPrint(
        '[Analytics] profile_loaded achievements=$achievementsCount '
        'unlocked=$unlockedAchievementsCount',
      );

  @override
  Future<void> trackTtsFailsafeTriggered({
    required String stage,
    required int itemCount,
    required String reason,
  }) async =>
      debugPrint(
        '[Analytics] tts_failsafe_triggered stage=$stage '
        'itemCount=$itemCount reason=$reason',
      );
}

class DebugCrashReporter implements CrashReporter {
  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? context,
  }) async =>
      debugPrint(
        '[CrashReporter] ${context ?? 'unknown'}: ${exception.runtimeType}',
      );

  @override
  void setUserId(String? userId) {}
}
