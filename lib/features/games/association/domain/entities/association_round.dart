import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/association/domain/entities/association_difficulty.dart';
import 'package:lexrush/features/games/association/domain/entities/association_option.dart';
import 'package:lexrush/features/games/association/domain/entities/association_type.dart';

class AssociationRound extends Equatable {
  const AssociationRound({
    required this.roundId,
    required this.targetWord,
    required this.correctAnswer,
    required this.explanation,
    required this.type,
    required this.difficulty,
    required this.options,
    required this.startedAt,
    this.contextHint,
    this.answered = false,
  });

  final int roundId;
  final String targetWord;
  final String correctAnswer;
  final String explanation;
  final AssociationType type;
  final AssociationDifficulty difficulty;
  final List<AssociationOption> options;
  final DateTime startedAt;
  final String? contextHint;
  final bool answered;

  AssociationRound copyWith({bool? answered}) {
    return AssociationRound(
      roundId: roundId,
      targetWord: targetWord,
      correctAnswer: correctAnswer,
      explanation: explanation,
      type: type,
      difficulty: difficulty,
      options: options,
      startedAt: startedAt,
      contextHint: contextHint,
      answered: answered ?? this.answered,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    roundId,
    targetWord,
    correctAnswer,
    explanation,
    type,
    difficulty,
    options,
    startedAt,
    contextHint,
    answered,
  ];
}
