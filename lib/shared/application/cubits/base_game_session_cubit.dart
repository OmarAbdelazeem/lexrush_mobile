import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexrush/shared/application/services/game_timer_manager.dart';

abstract class BaseGameSessionCubit<State> extends Cubit<State> {
  BaseGameSessionCubit(super.initialState);

  final GameTimerManager timerManager = GameTimerManager();

  @override
  Future<void> close() {
    debugPrint('[BaseGameSessionCubit] close -> disposing timer manager');
    timerManager.dispose();
    return super.close();
  }
}
