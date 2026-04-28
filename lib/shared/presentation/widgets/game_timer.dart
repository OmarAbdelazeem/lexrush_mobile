import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class GameTimer extends StatelessWidget {
  const GameTimer({
    required this.secondsLeft,
    super.key,
  });

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final bool isUrgent = secondsLeft <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isUrgent ? AppColors.error.withValues(alpha: 0.2) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isUrgent ? Border.all(color: AppColors.error) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.schedule_rounded,
            color: isUrgent ? AppColors.error : AppColors.accent,
          ),
          const SizedBox(width: 8),
          Text(
            '$secondsLeft',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
