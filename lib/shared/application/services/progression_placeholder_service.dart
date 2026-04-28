import 'package:flutter/foundation.dart';
import 'package:lexrush/shared/domain/contracts/progress_repository.dart';
import 'package:lexrush/shared/domain/entities/player_progress.dart';

class ProgressionPlaceholderService {
  const ProgressionPlaceholderService(this.repository);

  final ProgressRepository repository;

  Future<PlayerProgress> applySessionResult({required int xpEarned}) async {
    final PlayerProgress current = await repository.readProgress();
    final PlayerProgress next = current.copyWith(
      totalXp: current.totalXp + xpEarned,
      totalSessions: current.totalSessions + 1,
      // Streaks intentionally placeholder until real day logic is implemented.
      currentStreakDays: current.currentStreakDays,
      bestStreakDays: current.bestStreakDays,
      lastPlayedIso: DateTime.now().toIso8601String(),
    );
    debugPrint(
      '[ProgressionPlaceholderService] session saved xp=$xpEarned totalXp=${next.totalXp} sessions=${next.totalSessions}',
    );
    await repository.saveProgress(next);
    return next;
  }
}
