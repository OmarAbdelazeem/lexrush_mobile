import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_difficulty.dart';

class AntonymPair extends Equatable {
  const AntonymPair({
    required this.word,
    required this.antonym,
    required this.distractors,
    required this.difficulty,
    this.beginnerSafe = false,
    this.backendOptions,
    this.explanation,
  });

  final String word;
  final String antonym;
  final List<String> distractors;
  final AntonymDifficulty difficulty;
  final bool beginnerSafe;
  final List<AntonymPairOption>? backendOptions;
  final String? explanation;

  @override
  List<Object?> get props => <Object?>[
    word,
    antonym,
    distractors,
    difficulty,
    beginnerSafe,
    backendOptions,
    explanation,
  ];
}

class AntonymPairOption extends Equatable {
  const AntonymPairOption({
    required this.id,
    required this.word,
    required this.isCorrect,
  });

  final String id;
  final String word;
  final bool isCorrect;

  @override
  List<Object> get props => <Object>[id, word, isCorrect];
}
