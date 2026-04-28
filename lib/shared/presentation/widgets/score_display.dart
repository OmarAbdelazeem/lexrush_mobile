import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class ScoreDisplay extends StatelessWidget {
  const ScoreDisplay({
    required this.score,
    super.key,
  });

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text('Score', style: Theme.of(context).textTheme.bodyMedium),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              '$score',
              key: ValueKey<int>(score),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}
