import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_round_result.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';
import 'package:lexrush/shared/presentation/widgets/primary_button.dart';
import 'package:lexrush/shared/presentation/widgets/result_stat_tile.dart';

class CommasResultsScreen extends StatelessWidget {
  const CommasResultsScreen({
    required this.result,
    required this.onPlayAgain,
    required this.onBackToModes,
    super.key,
  });

  final CommasGameResult result;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToModes;

  @override
  Widget build(BuildContext context) {
    final stats = result.summary.stats;
    final List<CommaRoundResult> visibleReview = result.review
        .where(
          (CommaRoundResult item) => !item.completed || item.wrongCount > 0,
        )
        .take(8)
        .toList();
    final List<CommaRoundResult> fallbackReview = visibleReview.isEmpty
        ? result.review.take(6).toList()
        : visibleReview;

    return PortraitShell(
      title: 'Commas Results',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 6),
            Icon(Icons.format_quote_rounded, color: AppColors.accent, size: 58),
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
              label: 'Commas Placed',
              value: '${stats.correctAnswers}',
              icon: Icons.format_quote_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Wrong Taps',
              value: '${stats.missedWords}',
              icon: Icons.touch_app_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Sentences',
              value: '${stats.wordsSolved}',
              icon: Icons.subject_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Best Streak',
              value: '${stats.bestCombo}x',
              icon: Icons.local_fire_department_rounded,
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
            const SizedBox(height: 20),
            Text('Review', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Correct punctuation with the rule behind it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (fallbackReview.isEmpty)
              Text(
                'No comma attempts to review yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...fallbackReview.map(
                (CommaRoundResult item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReviewCard(item: item),
                ),
              ),
            const SizedBox(height: 16),
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

  final CommaRoundResult item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                item.completed
                    ? Icons.check_circle_rounded
                    : Icons.edit_note_rounded,
                color: item.completed ? AppColors.reward : AppColors.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item.correctCount}/${item.prompt.insertionPoints.length} commas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                item.prompt.ruleType.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LabelValue(
            label: 'Original',
            value: item.prompt.displayTextWithoutCommas,
          ),
          const SizedBox(height: 8),
          _LabelValue(
            label: 'Correct',
            value: item.prompt.correctTextWithCommas,
          ),
          const SizedBox(height: 8),
          Text(
            'Placed gaps: ${_formatIndexes(item.placedCommaIndexes)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Wrong gaps: ${_formatIndexes(item.wrongGapIndexes)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            item.prompt.explanation,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatIndexes(List<int> indexes) {
    if (indexes.isEmpty) return 'none';
    return indexes.map((int index) => 'after $index').join(', ');
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
