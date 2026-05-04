import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/association/domain/entities/association_outcome.dart';

class AssociationRoundResult extends Equatable {
  const AssociationRoundResult({
    required this.roundId,
    required this.targetWord,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.explanation,
    required this.outcome,
    required this.responseTimeMs,
  });

  final int roundId;
  final String targetWord;
  final String correctAnswer;
  final String? selectedAnswer;
  final String explanation;
  final AssociationOutcome outcome;
  final int? responseTimeMs;

  bool get wasCorrect => outcome == AssociationOutcome.correct;

  @override
  List<Object?> get props => <Object?>[
    roundId,
    targetWord,
    correctAnswer,
    selectedAnswer,
    explanation,
    outcome,
    responseTimeMs,
  ];
}
