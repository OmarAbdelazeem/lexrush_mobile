import 'package:equatable/equatable.dart';

class PlayerProgress extends Equatable {
  const PlayerProgress({
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.totalXp,
    required this.totalSessions,
    this.lastPlayedIso,
  });

  final int currentStreakDays;
  final int bestStreakDays;
  final int totalXp;
  final int totalSessions;
  final String? lastPlayedIso;

  factory PlayerProgress.initial() {
    return const PlayerProgress(
      currentStreakDays: 0,
      bestStreakDays: 0,
      totalXp: 0,
      totalSessions: 0,
      lastPlayedIso: null,
    );
  }

  PlayerProgress copyWith({
    int? currentStreakDays,
    int? bestStreakDays,
    int? totalXp,
    int? totalSessions,
    String? lastPlayedIso,
  }) {
    return PlayerProgress(
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      bestStreakDays: bestStreakDays ?? this.bestStreakDays,
      totalXp: totalXp ?? this.totalXp,
      totalSessions: totalSessions ?? this.totalSessions,
      lastPlayedIso: lastPlayedIso ?? this.lastPlayedIso,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        currentStreakDays,
        bestStreakDays,
        totalXp,
        totalSessions,
        lastPlayedIso,
      ];
}
