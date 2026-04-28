import 'package:lexrush/shared/domain/entities/game_mode.dart';

abstract class AnalyticsPort {
  Future<void> trackGameStarted(GameMode mode);
  Future<void> trackGameFinished(GameMode mode, {required int score, required int accuracy});
  Future<void> trackRoundOutcome(GameMode mode, String outcome);
}
