import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/association/domain/entities/association_difficulty.dart';
import 'package:lexrush/features/games/association/domain/entities/association_type.dart';

class AssociationPrompt extends Equatable {
  const AssociationPrompt({
    required this.targetWord,
    required this.correctAnswer,
    required this.wrongAnswer,
    required this.explanation,
    required this.type,
    required this.difficulty,
    this.beginnerSafe = false,
    this.contextHint,
  });

  final String targetWord;
  final String correctAnswer;
  final String wrongAnswer;
  final String explanation;
  final AssociationType type;
  final AssociationDifficulty difficulty;
  final bool beginnerSafe;
  final String? contextHint;

  @override
  List<Object?> get props => <Object?>[
    targetWord,
    correctAnswer,
    wrongAnswer,
    explanation,
    type,
    difficulty,
    beginnerSafe,
    contextHint,
  ];
}
