import 'package:lexrush/shared/domain/contracts/analytics_port.dart';
import 'package:lexrush/shared/domain/contracts/crash_reporter.dart';

class FakeAnalyticsPort implements AnalyticsPort {
  final List<Map<String, dynamic>> events = [];

  List<Map<String, dynamic>> eventsOf(String name) =>
      events.where((e) => e['event'] == name).toList();

  @override
  Future<void> trackAppStarted() async =>
      events.add({'event': 'app_started'});

  @override
  Future<void> trackAuthLoginSuccess({required String userId}) async =>
      events.add({'event': 'auth_login_success'});

  @override
  Future<void> trackAuthRegisterSuccess({required String userId}) async =>
      events.add({'event': 'auth_register_success'});

  @override
  Future<void> trackAuthLogout() async =>
      events.add({'event': 'auth_logout'});

  @override
  Future<void> trackGameStarted({
    required String gameId,
    required String source,
    required bool usedBackendPrompts,
  }) async =>
      events.add({
        'event': 'game_started',
        'gameId': gameId,
        'source': source,
        'usedBackendPrompts': usedBackendPrompts,
      });

  @override
  Future<void> trackGameCompleted({
    required String gameId,
    required int score,
    required double accuracy,
    required int durationSeconds,
    required bool usedBackendPrompts,
  }) async =>
      events.add({
        'event': 'game_completed',
        'gameId': gameId,
        'score': score,
        'accuracy': accuracy,
        'durationSeconds': durationSeconds,
        'usedBackendPrompts': usedBackendPrompts,
      });

  @override
  Future<void> trackResultSyncStatus({
    required String gameId,
    required String status,
    int? xpEarned,
  }) async =>
      events.add(<String, dynamic>{
        'event': 'result_sync_status',
        'gameId': gameId,
        'status': status,
        'xpEarned': xpEarned,
      }..removeWhere((_, v) => v == null));

  @override
  Future<void> trackBackendPromptBootstrap({
    required String gameId,
    required String outcome,
  }) async =>
      events.add({
        'event': 'backend_prompt_bootstrap',
        'gameId': gameId,
        'outcome': outcome,
      });

  @override
  Future<void> trackOfflineRetryDrain({
    required int startedCount,
    required int succeededCount,
    required int failedCount,
    int? removedDuplicateCount,
  }) async =>
      events.add(<String, dynamic>{
        'event': 'offline_retry_drain',
        'startedCount': startedCount,
        'succeededCount': succeededCount,
        'failedCount': failedCount,
        'removedDuplicateCount': removedDuplicateCount,
      }..removeWhere((_, v) => v == null));

  @override
  Future<void> trackTodayLoaded({
    required String status,
    required int completedRecommendedGames,
    required int totalRecommendedGames,
  }) async =>
      events.add({
        'event': 'today_loaded',
        'status': status,
        'completedRecommendedGames': completedRecommendedGames,
        'totalRecommendedGames': totalRecommendedGames,
      });

  @override
  Future<void> trackProfileLoaded({
    required int achievementsCount,
    required int unlockedAchievementsCount,
  }) async =>
      events.add({
        'event': 'profile_loaded',
        'achievementsCount': achievementsCount,
        'unlockedAchievementsCount': unlockedAchievementsCount,
      });

  @override
  Future<void> trackTtsFailsafeTriggered({
    required String stage,
    required int itemCount,
    required String reason,
  }) async =>
      events.add({
        'event': 'tts_failsafe_triggered',
        'stage': stage,
        'itemCount': itemCount,
        'reason': reason,
      });
}

class ThrowingAnalyticsPort implements AnalyticsPort {
  @override
  Future<void> trackAppStarted() => Future.error(Exception('analytics down'));
  @override
  Future<void> trackAuthLoginSuccess({required String userId}) =>
      Future.error(Exception('analytics down'));
  @override
  Future<void> trackAuthRegisterSuccess({required String userId}) =>
      Future.error(Exception('analytics down'));
  @override
  Future<void> trackAuthLogout() =>
      Future.error(Exception('analytics down'));
  @override
  Future<void> trackGameStarted({
    required String gameId,
    required String source,
    required bool usedBackendPrompts,
  }) => Future.error(Exception('analytics down'));
  @override
  Future<void> trackGameCompleted({
    required String gameId,
    required int score,
    required double accuracy,
    required int durationSeconds,
    required bool usedBackendPrompts,
  }) => Future.error(Exception('analytics down'));
  @override
  Future<void> trackResultSyncStatus({
    required String gameId,
    required String status,
    int? xpEarned,
  }) => Future.error(Exception('analytics down'));
  @override
  Future<void> trackBackendPromptBootstrap({
    required String gameId,
    required String outcome,
  }) => Future.error(Exception('analytics down'));
  @override
  Future<void> trackOfflineRetryDrain({
    required int startedCount,
    required int succeededCount,
    required int failedCount,
    int? removedDuplicateCount,
  }) => Future.error(Exception('analytics down'));
  @override
  Future<void> trackTodayLoaded({
    required String status,
    required int completedRecommendedGames,
    required int totalRecommendedGames,
  }) => Future.error(Exception('analytics down'));
  @override
  Future<void> trackProfileLoaded({
    required int achievementsCount,
    required int unlockedAchievementsCount,
  }) => Future.error(Exception('analytics down'));
  @override
  Future<void> trackTtsFailsafeTriggered({
    required String stage,
    required int itemCount,
    required String reason,
  }) => Future.error(Exception('analytics down'));
}

class FakeCrashReporter implements CrashReporter {
  final List<({Object exception, String? context})> captured = [];

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? context,
  }) async =>
      captured.add((exception: exception, context: context));

  @override
  void setUserId(String? userId) {}
}
