import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class ResultStatTile extends StatelessWidget {
  const ResultStatTile({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
