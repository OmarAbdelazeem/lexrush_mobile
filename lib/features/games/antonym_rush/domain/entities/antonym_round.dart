import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_difficulty.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/balloon_option.dart';

class AntonymRound extends Equatable {
  const AntonymRound({
    required this.roundId,
    required this.targetWord,
    required this.correctAnswer,
    required this.pairDifficulty,
    required this.options,
    required this.startedAt,
    this.answered = false,
    this.explanation,
  });

  final int roundId;
  final String targetWord;
  final String correctAnswer;
  final AntonymDifficulty pairDifficulty;
  final List<BalloonOption> options;
  final DateTime startedAt;
  final bool answered;
  final String? explanation;

  AntonymRound copyWith({bool? answered}) {
    return AntonymRound(
      roundId: roundId,
      targetWord: targetWord,
      correctAnswer: correctAnswer,
      pairDifficulty: pairDifficulty,
      options: options,
      startedAt: startedAt,
      answered: answered ?? this.answered,
      explanation: explanation,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    roundId,
    targetWord,
    correctAnswer,
    pairDifficulty,
    options,
    startedAt,
    answered,
    explanation,
  ];
}
