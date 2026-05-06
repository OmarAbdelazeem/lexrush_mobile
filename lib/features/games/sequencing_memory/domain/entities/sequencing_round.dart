import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_prompt.dart';

class SequencingRound extends Equatable {
  const SequencingRound({
    required this.roundId,
    required this.prompt,
    required this.partOne,
    required this.partTwo,
  });

  final int roundId;
  final SequencingPrompt prompt;
  final List<String> partOne;
  final List<String> partTwo;

  List<String> get combined => <String>[...partOne, ...partTwo];

  @override
  List<Object> get props => <Object>[roundId, prompt, partOne, partTwo];
}
