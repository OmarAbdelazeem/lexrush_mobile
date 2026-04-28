import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_difficulty.dart';

class AntonymPair extends Equatable {
  const AntonymPair({
    required this.word,
    required this.antonym,
    required this.distractors,
    required this.difficulty,
  });

  final String word;
  final String antonym;
  final List<String> distractors;
  final AntonymDifficulty difficulty;

  @override
  List<Object> get props => <Object>[word, antonym, distractors, difficulty];
}
