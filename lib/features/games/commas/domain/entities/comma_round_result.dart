import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_prompt.dart';

class CommaRoundResult extends Equatable {
  const CommaRoundResult({
    required this.prompt,
    required this.placedCommaIndexes,
    required this.wrongGapIndexes,
    required this.completed,
    required this.responseTimesMs,
  });

  final CommaPrompt prompt;
  final List<int> placedCommaIndexes;
  final List<int> wrongGapIndexes;
  final bool completed;
  final List<int> responseTimesMs;

  int get correctCount => placedCommaIndexes.length;
  int get wrongCount => wrongGapIndexes.length;

  @override
  List<Object> get props => <Object>[
    prompt,
    placedCommaIndexes,
    wrongGapIndexes,
    completed,
    responseTimesMs,
  ];
}
