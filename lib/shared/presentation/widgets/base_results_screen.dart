import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/presentation/widgets/primary_button.dart';
import 'package:lexrush/shared/presentation/widgets/result_stat_tile.dart';

class BaseResultsScreen extends StatelessWidget {
  const BaseResultsScreen({
    required this.result,
    required this.onPlayAgain,
    required this.onBackToModes,
    super.key,
  });

  final GameResult result;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToModes;

  @override
  Widget build(BuildContext context) {
    final String encouragement = result.stats.accuracy >= 90
        ? "Perfect accuracy! You're a word master."
        : result.stats.accuracy >= 70
            ? 'Great job! Keep up the momentum.'
            : result.stats.wordsSolved >= 10
                ? "Good effort! You're improving."
                : 'Keep practicing to boost your score.';

    return PortraitShell(
      title: 'Results',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 6),
            Icon(
              Icons.emoji_events_rounded,
              size: 56,
              color: AppColors.reward,
            ),
            const SizedBox(height: 8),
            Text(
              'Round Complete!',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${result.stats.score}',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            Text(
              'Final Score',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ResultStatTile(
              label: 'Accuracy',
              value: '${result.stats.accuracy}%',
              icon: Icons.track_changes_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Best Combo',
              value: '${result.stats.bestCombo}x',
              icon: Icons.local_fire_department_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Words Solved',
              value: '${result.stats.wordsSolved}',
              icon: Icons.menu_book_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Missed Words',
              value: '${result.stats.missedWords}',
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Avg Response',
              value: '${(result.stats.averageResponseTimeMs / 1000).toStringAsFixed(1)}s',
              icon: Icons.timer_outlined,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'XP Earned',
              value: '+${result.stats.xpEarned}',
              icon: Icons.workspace_premium_outlined,
            ),
            const SizedBox(height: 18),
            Text(
              encouragement,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              result.replayGoal.message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.accent,
                  ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            PrimaryButton(label: 'Play Again', onPressed: onPlayAgain),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onBackToModes,
              child: const Text('Back To Modes'),
            ),
          ],
        ),
      ),
    );
  }
}
