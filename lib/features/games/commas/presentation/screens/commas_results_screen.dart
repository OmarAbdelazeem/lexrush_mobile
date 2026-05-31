import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_round_result.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/presentation/widgets/primary_button.dart';
import 'package:lexrush/shared/presentation/widgets/result_stat_tile.dart';
import 'package:lexrush/shared/presentation/widgets/result_sync_status_banner.dart';

class CommasResultsScreen extends StatelessWidget {
  const CommasResultsScreen({
    required this.result,
    required this.onPlayAgain,
    required this.onBackToModes,
    this.syncHandle,
    super.key,
  });

  final CommasGameResult result;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToModes;
  final BackendResultSyncHandle? syncHandle;

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
            const SizedBox(height: 10),
            ResultSyncStatusBanner(syncHandle: syncHandle),
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
          _SentenceBlock(
            label: 'Original',
            value: item.prompt.displayTextWithoutCommas,
          ),
          const SizedBox(height: 10),
          _SentenceBlock(
            label: 'Correct',
            value: item.prompt.correctTextWithCommas,
            emphasized: true,
          ),
          const SizedBox(height: 12),
          _LearningNote(
            label: 'Your commas',
            value: _afterPhrase('You placed commas', item.placedCommaIndexes),
          ),
          const SizedBox(height: 5),
          _LearningNote(
            label: 'Correct answer',
            value: 'after ${_formatWords(item, _correctIndexes(item))}',
          ),
          const SizedBox(height: 5),
          _LearningNote(
            label: 'Wrong taps',
            value: item.wrongGapIndexes.isEmpty
                ? 'No wrong taps'
                : _afterPhrase('You tapped', item.wrongGapIndexes),
          ),
          const SizedBox(height: 5),
          _LearningNote(label: 'Rule', value: item.prompt.explanation),
        ],
      ),
    );
  }

  String _formatWords(CommaRoundResult item, List<int> indexes) {
    if (indexes.isEmpty) return 'none';
    final List<String> tokens = item.prompt.displayTextWithoutCommas.split(' ');
    final List<String> words = indexes
        .where((int index) => index >= 0 && index < tokens.length)
        .map((int index) => _cleanToken(tokens[index]))
        .toList();
    if (words.isEmpty) return 'none';
    return words.join(', ');
  }

  String _cleanToken(String token) {
    return token.replaceAll(RegExp(r'[,.!?;:]+$'), '');
  }

  List<int> _correctIndexes(CommaRoundResult item) {
    return item.prompt.insertionPoints
        .map((point) => point.afterTokenIndex)
        .toList();
  }

  String _afterPhrase(String prefix, List<int> indexes) {
    final String words = _formatWords(item, indexes);
    if (words == 'none') return '$prefix: none';
    return '$prefix after $words';
  }
}

class _SentenceBlock extends StatelessWidget {
  const _SentenceBlock({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: emphasized ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasized
              ? AppColors.accent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              height: 1.28,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningNote extends StatelessWidget {
  const _LearningNote({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            height: 1.28,
          ),
        ),
      ],
    );
  }
}
