import 'package:equatable/equatable.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';
import 'package:lexrush/shared/domain/entities/replay_goal.dart';

class GameResult extends Equatable {
  const GameResult({
    required this.stats,
    required this.replayGoal,
  });

  final GameSessionStats stats;
  final ReplayGoal replayGoal;

  @override
  List<Object> get props => <Object>[stats, replayGoal];
}
