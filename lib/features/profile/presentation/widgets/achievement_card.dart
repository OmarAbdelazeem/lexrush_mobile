import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/shared/data/backend/user_achievements_dtos.dart';

class AchievementCard extends StatelessWidget {
  const AchievementCard({required this.achievement, super.key});

  final UserAchievementDto achievement;

  @override
  Widget build(BuildContext context) {
    final double progressValue = _progressValue(achievement);
    final int progress = _nonNegative(achievement.progress);
    final int target = _nonNegative(achievement.target);
    final bool unlocked = achievement.isUnlocked;
    final Color accentColor = unlocked
        ? AppColors.reward
        : AppColors.textSecondary;
    final String? unlockedText = _formatUnlockedAt(achievement.unlockedAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _achievementIcon(achievement.iconKey),
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      achievement.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(unlocked: unlocked),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: AppColors.background.withValues(alpha: 0.72),
              color: unlocked ? AppColors.reward : AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$progress / $target',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                '${(progressValue * 100).round()}%',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (unlockedText != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              unlockedText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.reward,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.unlocked});

  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final Color color = unlocked ? AppColors.reward : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        unlocked ? 'Unlocked' : 'Locked',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

IconData _achievementIcon(String iconKey) {
  switch (iconKey) {
    case 'achievement_first_step':
      return Icons.flag_rounded;
    case 'achievement_getting_warmed_up':
    case 'achievement_warmed_up':
      return Icons.local_fire_department_rounded;
    case 'achievement_xp_starter':
      return Icons.bolt_rounded;
    case 'achievement_streak_spark':
      return Icons.whatshot_rounded;
    case 'achievement_grammar_start':
      return Icons.school_rounded;
    case 'achievement_perfect_focus':
      return Icons.center_focus_strong_rounded;
    default:
      return Icons.workspace_premium_rounded;
  }
}

double _progressValue(UserAchievementDto achievement) {
  if (achievement.target <= 0) {
    return achievement.isUnlocked ? 1 : 0;
  }
  final double value = achievement.progress / achievement.target;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

int _nonNegative(int value) => value < 0 ? 0 : value;

String? _formatUnlockedAt(String? value) {
  if (value == null || value.isEmpty) return null;
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  final DateTime local = parsed.toLocal();
  return 'Unlocked ${_monthName(local.month)} ${local.day}, ${local.year}';
}

String _monthName(int month) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}
