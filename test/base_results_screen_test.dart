import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/app/theme/app_theme.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';
import 'package:lexrush/shared/domain/entities/replay_goal.dart';
import 'package:lexrush/shared/presentation/widgets/base_results_screen.dart';

void main() {
  for (final Size viewport in <Size>[
    const Size(390, 640),
    const Size(360, 640),
  ]) {
    testWidgets(
      'BaseResultsScreen scrolls with success banner at ${viewport.width}x${viewport.height}',
      (WidgetTester tester) async {
        final BackendResultSyncHandle handle = BackendResultSyncHandle();
        handle.setStatus(const BackendSyncStatus.synced(xpEarned: 37));
        addTearDown(handle.dispose);

        await _pumpResultsScreen(
          tester,
          viewport: viewport,
          syncHandle: handle,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Progress synced · +37 XP saved'), findsOneWidget);

        await tester.ensureVisible(find.text('Play Again'));
        await tester.tap(find.text('Play Again'));
        await tester.pump();
        expect(_playAgainTaps, 1);

        await tester.ensureVisible(find.text('Back To Modes'));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 2));
      },
    );
  }

  testWidgets('BaseResultsScreen scrolls with auth-required banner', (
    WidgetTester tester,
  ) async {
    final BackendResultSyncHandle handle = BackendResultSyncHandle();
    handle.setStatus(const BackendSyncStatus.authRequired());
    addTearDown(handle.dispose);

    await _pumpResultsScreen(
      tester,
      viewport: const Size(360, 640),
      syncHandle: handle,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sign in to save progress'), findsOneWidget);

    await tester.ensureVisible(find.text('Play Again'));
    await tester.tap(find.text('Play Again'));
    await tester.pump();
    expect(_playAgainTaps, 1);

    await tester.ensureVisible(find.text('Back To Modes'));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });
}

int _playAgainTaps = 0;

Future<void> _pumpResultsScreen(
  WidgetTester tester, {
  required Size viewport,
  required BackendResultSyncHandle syncHandle,
}) async {
  _playAgainTaps = 0;
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: BaseResultsScreen(
        result: _result(),
        syncHandle: syncHandle,
        onPlayAgain: () => _playAgainTaps += 1,
        onBackToModes: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
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
