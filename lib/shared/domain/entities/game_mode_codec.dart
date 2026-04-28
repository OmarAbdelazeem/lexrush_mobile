import 'package:lexrush/shared/domain/entities/game_mode.dart';

abstract final class GameModeCodec {
  static String toPath(GameMode mode) {
    switch (mode) {
      case GameMode.antonymRush:
        return 'antonym-rush';
      case GameMode.synonymStorm:
        return 'synonym-storm';
      case GameMode.definitionMatch:
        return 'definition-match';
    }
  }

  static GameMode? fromPath(String value) {
    switch (value) {
      case 'antonym-rush':
        return GameMode.antonymRush;
      case 'synonym-storm':
        return GameMode.synonymStorm;
      case 'definition-match':
        return GameMode.definitionMatch;
      default:
        return null;
    }
  }
}
