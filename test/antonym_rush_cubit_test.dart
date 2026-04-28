import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_state.dart';

void main() {
  group('AntonymRushCubit lifecycle', () {
    test('start initializes playable state', () {
      final AntonymRushCubit cubit = AntonymRushCubit();

      cubit.start();

      expect(cubit.state.status, AntonymRushStatus.playing);
      expect(cubit.state.currentRound, isNotNull);
      expect(cubit.state.timeLeft, 60);
      cubit.close();
    });

    test('pause and resume preserve active session', () {
      final AntonymRushCubit cubit = AntonymRushCubit();

      cubit.start();
      cubit.pause();
      expect(cubit.state.status, AntonymRushStatus.paused);

      cubit.resume();
      expect(cubit.state.status, AntonymRushStatus.playing);
      expect(cubit.state.currentRound, isNotNull);
      cubit.close();
    });

    test('endGame emits ended with result', () {
      final AntonymRushCubit cubit = AntonymRushCubit();

      cubit.start();
      cubit.endGame();

      expect(cubit.state.status, AntonymRushStatus.ended);
      expect(cubit.state.gameResult, isNotNull);
      cubit.close();
    });
  });
}
