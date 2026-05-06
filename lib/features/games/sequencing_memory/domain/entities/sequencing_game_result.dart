import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_round_result.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';

class SequencingGameResult extends Equatable {
  const SequencingGameResult({
    required this.summary,
    required this.review,
    required this.sequencesCompleted,
    required this.perfectStages,
    required this.longestSequenceRemembered,
    required this.replayCount,
    required this.averageRecallTimeMs,
  });

  final GameResult summary;
  final List<SequencingRoundResult> review;
  final int sequencesCompleted;
  final int perfectStages;
  final int longestSequenceRemembered;
  final int replayCount;
  final int averageRecallTimeMs;

  @override
  List<Object> get props => <Object>[
    summary,
    review,
    sequencesCompleted,
    perfectStages,
    longestSequenceRemembered,
    replayCount,
    averageRecallTimeMs,
  ];
}
