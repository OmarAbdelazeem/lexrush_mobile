import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_game_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_round_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_stage.dart';
import 'package:lexrush/shared/presentation/widgets/primary_button.dart';
import 'package:lexrush/shared/presentation/widgets/result_stat_tile.dart';

class SequencingMemoryResultsScreen extends StatelessWidget {
  const SequencingMemoryResultsScreen({
    required this.result,
    required this.onPlayAgain,
    required this.onBackToModes,
    super.key,
  });

  final SequencingGameResult result;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToModes;

  @override
  Widget build(BuildContext context) {
    final stats = result.summary.stats;
    final List<SequencingRoundResult> combinedReview = result.review
        .where((SequencingRoundResult item) => item.stage.isCombined)
        .toList(growable: false);
    final List<SequencingRoundResult> practiceMisses = result.review
        .where(
          (SequencingRoundResult item) =>
              !item.perfect && !item.stage.isCombined,
        )
        .toList(growable: false);
    final List<SequencingRoundResult> visibleReview = <SequencingRoundResult>[
      ...combinedReview,
      ...practiceMisses,
    ].take(9).toList(growable: false);

    return PortraitShell(
      title: 'Sequencing Results',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 4),
            Icon(Icons.route_rounded, size: 56, color: AppColors.accent),
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
              label: 'Routes Completed',
              value: '${result.sequencesCompleted}',
              icon: Icons.alt_route_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Perfect Stages',
              value: '${result.perfectStages}',
              icon: Icons.verified_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Longest Remembered',
              value: '${result.longestSequenceRemembered} steps',
              icon: Icons.format_list_numbered_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Replays Used',
              value: '${result.replayCount}',
              icon: Icons.replay_rounded,
            ),
            const SizedBox(height: 10),
            ResultStatTile(
              label: 'Avg Recall',
              value:
                  '${(result.averageRecallTimeMs / 1000).toStringAsFixed(1)}s',
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
            const SizedBox(height: 18),
            Text('Review', style: Theme.of(context).textTheme.titleLarge),
            Text(
              'Combined recall first, then practice chunks that need work.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            if (visibleReview.isEmpty)
              Text(
                'Every stage was perfect.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...visibleReview.map(
                (SequencingRoundResult item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SequencingReviewCard(item: item),
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

class _SequencingReviewCard extends StatelessWidget {
  const _SequencingReviewCard({required this.item});

  final SequencingRoundResult item;

  @override
  Widget build(BuildContext context) {
    final String stageName = switch (item.stage) {
      SequencingStage.arrangePartOne => 'Part One',
      SequencingStage.arrangePartTwo => 'Part Two',
      SequencingStage.arrangeCombined => 'Combined Recall',
      _ => 'Recall',
    };
    final Color color = item.perfect ? AppColors.reward : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                item.perfect
                    ? Icons.check_circle_rounded
                    : Icons.fact_check_rounded,
                color: color,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$stageName • Route ${item.roundId}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${item.correctPositions}/${item.totalPositions}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Replay count: ${item.replayCount}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text('Your order', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          ...List<Widget>.generate(item.correctOrder.length, (int index) {
            final bool correct = item.isCorrectAt(index);
            final String user = index < item.userOrder.length
                ? item.userOrder[index]
                : 'Missing step';
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _OrderRow(index: index, text: user, correct: correct),
            );
          }),
          const SizedBox(height: 8),
          Text('Correct order', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          ...List<Widget>.generate(item.correctOrder.length, (int index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${index + 1}. ${item.correctOrder[index]}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.reward,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.index,
    required this.text,
    required this.correct,
  });

  final int index;
  final String text;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final Color color = correct ? AppColors.reward : AppColors.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              correct ? Icons.check_rounded : Icons.close_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${index + 1}. $text',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
