import 'package:equatable/equatable.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_round_result.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';

class CommasGameResult extends Equatable {
  const CommasGameResult({required this.summary, required this.review});

  final GameResult summary;
  final List<CommaRoundResult> review;

  @override
  List<Object> get props => <Object>[summary, review];
}
