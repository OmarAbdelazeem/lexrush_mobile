import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/games/association/domain/entities/association_game_result.dart';
import 'package:lexrush/features/games/association/domain/entities/association_outcome.dart';
import 'package:lexrush/features/games/association/domain/entities/association_round_result.dart';
import 'package:lexrush/shared/presentation/widgets/primary_button.dart';
import 'package:lexrush/shared/presentation/widgets/result_stat_tile.dart';

class AssociationResultsScreen extends StatelessWidget {
  const AssociationResultsScreen({
    required this.result,
    required this.onPlayAgain,
    required this.onBackToModes,
    super.key,
  });

  final AssociationGameResult result;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToModes;

  @override
  Widget build(BuildContext context) {
    final stats = result.summary.stats;
    final List<AssociationRoundResult> review = result.review
        .where((AssociationRoundResult item) => !item.wasCorrect)
        .toList();
    final List<AssociationRoundResult> visibleReview = review.isEmpty
        ? result.review.take(6).toList()
        : review.take(8).toList();

    return PortraitShell(
      title: 'Association Results',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 4),
            Icon(Icons.hub_rounded, size: 54, color: AppColors.reward),
            const SizedBox(height: 8),
            Text(
              '${stats.score}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Final Score',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ResultStatTile(
              label: 'Accuracy',
              value: '${stats.accuracy}%',
              icon: Icons.track_changes_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Best Combo',
              value: '${stats.bestCombo}x',
              icon: Icons.local_fire_department_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Words Solved',
              value: '${stats.wordsSolved}',
              icon: Icons.menu_book_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Missed Words',
              value: '${stats.missedWords}',
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Avg Response',
              value:
                  '${(stats.averageResponseTimeMs / 1000).toStringAsFixed(1)}s',
              icon: Icons.timer_outlined,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'XP Earned',
              value: '+${stats.xpEarned}',
              icon: Icons.workspace_premium_outlined,
            ),
            const SizedBox(height: 18),
            Text(
              result.summary.replayGoal.message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.psychology_alt_rounded, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Reviewed words',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${result.review.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              review.isEmpty ? 'Review Highlights' : 'Review Misses First',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (visibleReview.isEmpty)
              Text(
                'No rounds to review yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...visibleReview.map(
                (AssociationRoundResult item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewCard(item: item),
                ),
              ),
            const SizedBox(height: 14),
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item});

  final AssociationRoundResult item;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (item.outcome) {
      AssociationOutcome.correct => AppColors.reward,
      AssociationOutcome.wrong => AppColors.error,
      AssociationOutcome.missed => AppColors.accent,
    };
    final IconData icon = switch (item.outcome) {
      AssociationOutcome.correct => Icons.check_circle_rounded,
      AssociationOutcome.wrong => Icons.cancel_rounded,
      AssociationOutcome.missed => Icons.timer_off_rounded,
    };
    final String selected = item.selectedAnswer ?? 'No answer';
    final String outcomeLabel = switch (item.outcome) {
      AssociationOutcome.correct => 'Correct',
      AssociationOutcome.wrong => 'Wrong',
      AssociationOutcome.missed => 'Missed',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.targetWord,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                outcomeLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Selected: $selected',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.reward.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.reward.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                'Correct: ${item.correctAnswer}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.reward,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(item.explanation, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
