import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_difficulty.dart';

enum SequencingTheme { route, errands, campus }

class SequencingPrompt extends Equatable {
  const SequencingPrompt({
    required this.id,
    required this.items,
    required this.theme,
    required this.difficulty,
    this.beginnerSafe = false,
  });

  final String id;
  final List<String> items;
  final SequencingTheme theme;
  final SequencingDifficulty difficulty;
  final bool beginnerSafe;

  @override
  List<Object> get props => <Object>[
    id,
    items,
    theme,
    difficulty,
    beginnerSafe,
  ];
}
