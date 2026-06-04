import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/features/games/commas/application/cubit/commas_state.dart';

class CommaFeedback extends StatelessWidget {
  const CommaFeedback({
    required this.status,
    required this.feedbackText,
    required this.explanation,
    super.key,
  });

  final CommasStatus status;
  final String? feedbackText;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final String text = feedbackText ?? '';
    final bool visible = text.isNotEmpty;
    final Color color = switch (status) {
      CommasStatus.wrongFeedback => AppColors.error,
      CommasStatus.sentenceComplete => AppColors.reward,
      _ => AppColors.accent,
    };
    final String displayText = status == CommasStatus.wrongFeedback
        ? ''
        : status == CommasStatus.correctFeedback
        ? ''
        : text;
    final String explanationText = status == CommasStatus.sentenceComplete
        ? explanation?.trim() ?? ''
        : '';
    final bool showContainer =
        visible && (displayText.isNotEmpty || explanationText.isNotEmpty);

    return AnimatedOpacity(
      opacity: showContainer ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: BoxConstraints(minHeight: showContainer ? 30 : 8),
        padding: EdgeInsets.symmetric(
          horizontal: showContainer ? 10 : 0,
          vertical: showContainer ? 6 : 0,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: showContainer ? 0.10 : 0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: showContainer ? 0.30 : 0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (displayText.isNotEmpty)
              Text(
                displayText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            if (explanationText.isNotEmpty) ...<Widget>[
              if (displayText.isNotEmpty) const SizedBox(height: 4),
              Text(
                explanationText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
