import 'package:lexrush/shared/domain/entities/game_session_stats.dart';

abstract class LexRushGameController {
  void start();
  void pause();
  void resume();
  void restart();
  void submitAnswer(String answerId);
  GameSessionStats? finish();
}
