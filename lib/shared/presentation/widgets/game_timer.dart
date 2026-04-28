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
    return AnimatedScale(
      scale: isUrgent ? 1.06 : 1,
      duration: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isUrgent ? AppColors.error.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUrgent ? AppColors.error : Colors.transparent,
          ),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isUrgent ? AppColors.error : AppColors.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
