import 'package:lexrush/shared/domain/entities/game_definition.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';

abstract final class GameCatalog {
  static const List<GameDefinition> games = <GameDefinition>[
    GameDefinition(
      id: 'antonym_rush',
      mode: GameMode.antonymRush,
      title: 'Antonym Rush',
      description: 'Find opposite words',
      category: 'Vocabulary',
    ),
    GameDefinition(
      id: 'synonym_storm',
      mode: GameMode.synonymStorm,
      title: 'Synonym Storm',
      description: 'Match similar words',
      category: 'Vocabulary',
    ),
    GameDefinition(
      id: 'definition_match',
      mode: GameMode.definitionMatch,
      title: 'Definition Match',
      description: 'Choose the best definition',
      category: 'Vocabulary',
    ),
    GameDefinition(
      id: 'association',
      mode: GameMode.association,
      title: 'Association',
      description: 'Link related words',
      category: 'Vocabulary',
    ),
  ];
}
