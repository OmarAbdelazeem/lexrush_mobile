import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/app/theme/app_theme.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';
import 'package:lexrush/shared/domain/entities/replay_goal.dart';
import 'package:lexrush/shared/presentation/widgets/base_results_screen.dart';

void main() {
  testWidgets('BaseResultsScreen scrolls on compact screens with sync banner', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final BackendResultSyncHandle handle = BackendResultSyncHandle();
    handle.setStatus(const BackendSyncStatus.synced(xpEarned: 37));
    addTearDown(handle.dispose);

    int playAgainTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: BaseResultsScreen(
          result: _result(),
          syncHandle: handle,
          onPlayAgain: () => playAgainTaps += 1,
          onBackToModes: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Progress synced · +37 XP saved'), findsOneWidget);

    await tester.ensureVisible(find.text('Play Again'));
    await tester.tap(find.text('Play Again'));
    expect(playAgainTaps, 1);
    await tester.pump(const Duration(seconds: 2));
  });
}

GameResult _result() {
  return const GameResult(
    stats: GameSessionStats(
      score: 1200,
      accuracy: 80,
      bestCombo: 7,
      xpEarned: 125,
      totalAttempts: 12,
      correctAnswers: 10,
      wordsSolved: 10,
      missedWords: 2,
      averageResponseTimeMs: 1850,
    ),
    replayGoal: ReplayGoal('Beat your best combo next round.'),
  );
}
