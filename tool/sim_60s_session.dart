// Headless 60-second simulation of an Antonym Rush session that drives the
// real Cubit with real Timers. The simulated player taps the correct option
// after a delay sampled from a deterministic pseudo-random stream.
//
// Run with:
//   flutter test tool/sim_60s_session.dart
//
// This is a development tool, not a regression test.

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_state.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_round.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/balloon_option.dart';

void main() {
  test('60s session simulation', () async {
    final AntonymRushCubit cubit = AntonymRushCubit();
    final Random rng = Random(42);
    final List<int> tapLatenciesMs = <int>[];
    final Set<int> countedRoundIds = <int>{};
    final Map<int, int> roundsByOptionCount = <int, int>{3: 0, 4: 0};
    int? lastDrivenRoundId;

    void scheduleTapForRound(AntonymRound round) {
      if (lastDrivenRoundId == round.roundId) return;
      lastDrivenRoundId = round.roundId;
      if (countedRoundIds.add(round.roundId)) {
        roundsByOptionCount[round.options.length] =
            (roundsByOptionCount[round.options.length] ?? 0) + 1;
      }
      // 70% accuracy target: occasional "no tap" -> miss, occasional wrong tap.
      // Latency 1200-2600ms with mean ~1.9s mirrors target avg response.
      final int latencyMs = 1200 + rng.nextInt(1400);
      final double roll = rng.nextDouble();
      tapLatenciesMs.add(latencyMs);
      Timer(Duration(milliseconds: latencyMs), () {
        if (cubit.state.status != AntonymRushStatus.playing) return;
        final AntonymRound? current = cubit.state.currentRound;
        if (current == null ||
            current.roundId != round.roundId ||
            current.answered) {
          return;
        }
        if (roll < 0.06) {
          // Drop the round (no tap).
          return;
        }
        BalloonOption pick;
        if (roll < 0.18) {
          pick = current.options.firstWhere((BalloonOption o) => !o.isCorrect);
        } else {
          pick = current.options.firstWhere((BalloonOption o) => o.isCorrect);
        }
        cubit.submitAnswer(pick.id);
      });
    }

    final StreamSubscription<AntonymRushState> sub = cubit.stream.listen((
      AntonymRushState state,
    ) {
      final AntonymRound? round = state.currentRound;
      if (state.status == AntonymRushStatus.playing &&
          round != null &&
          !round.answered) {
        scheduleTapForRound(round);
      }
    });

    cubit.start();
    final Completer<void> done = Completer<void>();
    late StreamSubscription<AntonymRushState> endedSub;
    endedSub = cubit.stream.listen((AntonymRushState state) {
      if (state.status == AntonymRushStatus.ended) {
        if (!done.isCompleted) done.complete();
        endedSub.cancel();
      }
    });

    await done.future.timeout(const Duration(seconds: 75));

    final state = cubit.state;
    final result = state.gameResult;
    // ignore: avoid_print
    print('--- 60s simulation summary ---');
    // ignore: avoid_print
    print(
      'score=${state.score} accuracy=${result?.stats.accuracy}% bestCombo=${state.bestCombo}',
    );
    // ignore: avoid_print
    print(
      'wordsSolved=${state.wordsSolved} missedWords=${state.missedWords} '
      'wrong=${state.wrongAnswers} attempts=${state.totalAttempts}',
    );
    // ignore: avoid_print
    print('avgResponseMs=${result?.stats.averageResponseTimeMs}');
    // ignore: avoid_print
    print(
      'rounds3=${roundsByOptionCount[3] ?? 0} rounds4=${roundsByOptionCount[4] ?? 0}',
    );

    await sub.cancel();
    await cubit.close();
  }, timeout: const Timeout(Duration(seconds: 90)));
}
