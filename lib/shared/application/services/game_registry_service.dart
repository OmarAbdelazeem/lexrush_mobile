import 'package:flutter/foundation.dart';
import 'package:lexrush/shared/domain/entities/game_catalog.dart';
import 'package:lexrush/shared/domain/entities/game_definition.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';

class GameRegistryService {
  GameRegistryService({List<GameDefinition>? seedGames}) {
    if (seedGames != null) {
      for (final GameDefinition game in seedGames) {
        register(game);
      }
    }
    debugPrint('[GameRegistryService] initialized with ${_games.length} game(s)');
  }

  final Map<String, GameDefinition> _games = <String, GameDefinition>{};

  void register(GameDefinition definition) {
    _games[definition.id] = definition;
    debugPrint(
      '[GameRegistryService] register id=${definition.id} locked=${definition.isLocked}',
    );
  }

  List<GameDefinition> listAll() {
    final List<GameDefinition> values = _games.values.toList(growable: false);
    debugPrint('[GameRegistryService] listAll count=${values.length}');
    return values;
  }

  GameDefinition? byMode(GameMode mode) {
    final GameDefinition? game = _games.values.where((g) => g.mode == mode).firstOrNull;
    debugPrint('[GameRegistryService] byMode mode=$mode found=${game != null}');
    return game;
  }

  void registerAll(Iterable<GameDefinition> games) {
    for (final GameDefinition game in games) {
      register(game);
    }
    debugPrint('[GameRegistryService] registerAll total=${_games.length}');
  }

  bool hasMode(GameMode mode) => byMode(mode) != null;

  static GameRegistryService defaultRegistry() {
    debugPrint('[GameRegistryService] building defaultRegistry');
    final GameRegistryService registry = GameRegistryService();
    registry.registerAll(GameCatalog.games);
    return registry;
  }
}
