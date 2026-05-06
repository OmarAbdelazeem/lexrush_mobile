import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_stage.dart';

class SequencingRoundResult extends Equatable {
  const SequencingRoundResult({
    required this.roundId,
    required this.stage,
    required this.correctOrder,
    required this.userOrder,
    required this.correctPositions,
    required this.pointsEarned,
    required this.perfect,
    required this.recallTimeMs,
    required this.replayCount,
  });

  final int roundId;
  final SequencingStage stage;
  final List<String> correctOrder;
  final List<String> userOrder;
  final int correctPositions;
  final int pointsEarned;
  final bool perfect;
  final int recallTimeMs;
  final int replayCount;

  int get totalPositions => correctOrder.length;

  bool isCorrectAt(int index) {
    if (index < 0 ||
        index >= correctOrder.length ||
        index >= userOrder.length) {
      return false;
    }
    return correctOrder[index] == userOrder[index];
  }

  @override
  List<Object> get props => <Object>[
    roundId,
    stage,
    correctOrder,
    userOrder,
    correctPositions,
    pointsEarned,
    perfect,
    recallTimeMs,
    replayCount,
  ];
}
