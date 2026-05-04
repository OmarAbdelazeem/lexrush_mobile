import 'package:equatable/equatable.dart';

class AssociationOption extends Equatable {
  const AssociationOption({
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
