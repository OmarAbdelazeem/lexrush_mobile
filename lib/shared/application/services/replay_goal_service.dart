import 'package:flutter/foundation.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';
import 'package:lexrush/shared/domain/entities/replay_goal.dart';

class ReplayGoalService {
  const ReplayGoalService();

  ReplayGoal buildGoal(GameSessionStats stats) {
    debugPrint(
      '[ReplayGoalService] buildGoal accuracy=${stats.accuracy} bestCombo=${stats.bestCombo} words=${stats.wordsSolved}',
    );

    if (stats.accuracy < 75) {
      return const ReplayGoal('Next goal: Reach 75% accuracy');
    }
    if (stats.bestCombo < 12) {
      return ReplayGoal('Next goal: Beat your ${stats.bestCombo}x combo');
    }
    if (stats.wordsSolved < 20) {
      return const ReplayGoal('Next goal: Solve 20 words');
    }
    return const ReplayGoal('Next goal: Reach 80% accuracy');
  }
}
