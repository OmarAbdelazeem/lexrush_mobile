import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class ComboMeter extends StatelessWidget {
  const ComboMeter({
    required this.combo,
    super.key,
  });

  final int combo;

  @override
  Widget build(BuildContext context) {
    final double progress = (combo / 10).clamp(0, 1).toDouble();
    final bool hot = combo >= 5;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Combo', style: Theme.of(context).textTheme.bodyMedium),
              Text(
                '${combo}x',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: hot ? AppColors.reward : AppColors.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(
                hot ? AppColors.reward : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
