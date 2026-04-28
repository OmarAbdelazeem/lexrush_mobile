import 'package:equatable/equatable.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';

class GameDefinition extends Equatable {
  const GameDefinition({
    required this.id,
    required this.mode,
    required this.title,
    required this.description,
    required this.category,
    this.isLocked = false,
  });

  final String id;
  final GameMode mode;
  final String title;
  final String description;
  final String category;
  final bool isLocked;

  @override
  List<Object> get props => <Object>[
        id,
        mode,
        title,
        description,
        category,
        isLocked,
      ];
}
