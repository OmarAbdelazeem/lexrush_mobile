import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_insertion_point.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_rule_type.dart';

class CommaPrompt extends Equatable {
  const CommaPrompt({
    required this.id,
    required this.displayTextWithoutCommas,
    required this.correctTextWithCommas,
    required this.insertionPoints,
    required this.ruleType,
    required this.difficulty,
    required this.beginnerSafe,
    required this.explanation,
  });

  final String id;
  final String displayTextWithoutCommas;
  final String correctTextWithCommas;
  final List<CommaInsertionPoint> insertionPoints;
  final CommaRuleType ruleType;
  final CommaDifficulty difficulty;
  final bool beginnerSafe;
  final String explanation;

  @override
  List<Object> get props => <Object>[
    id,
    displayTextWithoutCommas,
    correctTextWithCommas,
    insertionPoints,
    ruleType,
    difficulty,
    beginnerSafe,
    explanation,
  ];
}
