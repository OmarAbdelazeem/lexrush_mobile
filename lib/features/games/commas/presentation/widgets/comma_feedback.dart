import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/features/games/commas/application/cubit/commas_state.dart';

class CommaFeedback extends StatelessWidget {
  const CommaFeedback({
    required this.status,
    required this.feedbackText,
    super.key,
  });

  final CommasStatus status;
  final String? feedbackText;

  @override
  Widget build(BuildContext context) {
    final String text = feedbackText ?? '';
    final bool visible = text.isNotEmpty;
    final Color color = switch (status) {
      CommasStatus.wrongFeedback => AppColors.error,
      CommasStatus.sentenceComplete => AppColors.reward,
      _ => AppColors.accent,
    };

    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: visible ? 0.16 : 0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: visible ? 0.42 : 0),
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
