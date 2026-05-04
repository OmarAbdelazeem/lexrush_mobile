// Headless 60-second simulation of an Association session that drives the real
// Cubit with real timers. The simulated player taps after deterministic delays.
//
// Run with:
//   flutter test tool/sim_association_60s_session.dart
//
// This is a development tool, not a regression test.

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/association/application/cubit/association_cubit.dart';
import 'package:lexrush/features/games/association/application/cubit/association_state.dart';
import 'package:lexrush/features/games/association/domain/entities/association_difficulty.dart';
import 'package:lexrush/features/games/association/domain/entities/association_option.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round.dart';

void main() {
  test(
    '60s association session simulation',
    () async {
      final AssociationCubit cubit = AssociationCubit();
      final Random rng = Random(72);
      final Map<AssociationDifficulty, int> roundsByDifficulty =
          <AssociationDifficulty, int>{
            AssociationDifficulty.easy: 0,
            AssociationDifficulty.medium: 0,
            AssociationDifficulty.hard: 0,
          };
      int? lastDrivenRoundId;

      void scheduleTapForRound(AssociationRound round) {
        if (lastDrivenRoundId == round.roundId) return;
        lastDrivenRoundId = round.roundId;
        roundsByDifficulty[round.difficulty] =
            (roundsByDifficulty[round.difficulty] ?? 0) + 1;
        final int latencyMs = 900 + rng.nextInt(900);
        final double roll = rng.nextDouble();

        Timer(Duration(milliseconds: latencyMs), () {
          if (cubit.state.status != AssociationStatus.playing) return;
          final AssociationRound? current = cubit.state.currentRound;
          if (current == null ||
              current.roundId != round.roundId ||
              current.answered) {
            return;
          }
          if (roll < 0.08) {
            return;
          }
          final AssociationOption pick = roll < 0.20
              ? current.options.firstWhere(
                  (AssociationOption option) => !option.isCorrect,
                )
              : current.options.firstWhere(
                  (AssociationOption option) => option.isCorrect,
                );
          cubit.submitAnswer(pick.id);
        });
      }

      final StreamSubscription<AssociationState> sub = cubit.stream.listen((
        AssociationState state,
      ) {
        final AssociationRound? round = state.currentRound;
        if (state.status == AssociationStatus.playing &&
            round != null &&
            !round.answered) {
          scheduleTapForRound(round);
        }
      });

      cubit.start();
      final Completer<void> done = Completer<void>();
      late StreamSubscription<AssociationState> endedSub;
      endedSub = cubit.stream.listen((AssociationState state) {
        if (state.status == AssociationStatus.finished) {
          if (!done.isCompleted) done.complete();
          endedSub.cancel();
        }
      });

      await done.future.timeout(const Duration(seconds: 75));

      final AssociationState state = cubit.state;
      final result = state.result;
      // ignore: avoid_print
      print('--- Association 60s simulation summary ---');
      // ignore: avoid_print
      print(
        'score=${state.score} accuracy=${result?.summary.stats.accuracy}% bestCombo=${state.bestCombo}',
      );
      // ignore: avoid_print
      print(
        'wordsSolved=${state.wordsSolved} missedWords=${state.missedWords} '
        'wrong=${state.wrongAnswers} attempts=${state.totalAttempts}',
      );
      // ignore: avoid_print
      print('avgResponseMs=${result?.summary.stats.averageResponseTimeMs}');
      // ignore: avoid_print
      print(
        'roundsEasy=${roundsByDifficulty[AssociationDifficulty.easy] ?? 0} '
        'roundsMedium=${roundsByDifficulty[AssociationDifficulty.medium] ?? 0} '
        'roundsHard=${roundsByDifficulty[AssociationDifficulty.hard] ?? 0}',
      );
      // ignore: avoid_print
      print('reviewItems=${result?.review.length}');

      await sub.cancel();
      await cubit.close();
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
