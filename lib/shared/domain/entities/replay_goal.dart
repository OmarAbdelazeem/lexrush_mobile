import 'package:equatable/equatable.dart';

class ReplayGoal extends Equatable {
  const ReplayGoal(this.message);

  final String message;

  @override
  List<Object> get props => <Object>[message];
}
