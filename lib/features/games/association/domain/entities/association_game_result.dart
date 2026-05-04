import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round_result.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';

class AssociationGameResult extends Equatable {
  const AssociationGameResult({required this.summary, required this.review});

  final GameResult summary;
  final List<AssociationRoundResult> review;

  @override
  List<Object> get props => <Object>[summary, review];
}
