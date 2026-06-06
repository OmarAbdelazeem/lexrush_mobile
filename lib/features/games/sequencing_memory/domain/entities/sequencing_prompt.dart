import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_difficulty.dart';

enum SequencingTheme { route, errands, campus }

class SequencingBackendItem extends Equatable {
  const SequencingBackendItem({required this.id, required this.text});

  final String id;
  final String text;

  @override
  List<Object> get props => <Object>[id, text];
}

class SequencingPrompt extends Equatable {
  const SequencingPrompt({
    required this.id,
    required this.items,
    required this.theme,
    required this.difficulty,
    this.beginnerSafe = false,
    this.memoryHint,
    this.explanation,
    this.backendItems,
    this.correctOrderIds,
  });

  final String id;
  final List<String> items;
  final SequencingTheme theme;
  final SequencingDifficulty difficulty;
  final bool beginnerSafe;
  final String? memoryHint;
  final String? explanation;
  final List<SequencingBackendItem>? backendItems;
  final List<String>? correctOrderIds;

  @override
  List<Object> get props => <Object>[
    id,
    items,
    theme,
    difficulty,
    beginnerSafe,
  ];
}
