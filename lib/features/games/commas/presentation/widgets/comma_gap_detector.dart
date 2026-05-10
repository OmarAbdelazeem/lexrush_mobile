import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class CommaGapDetector extends StatelessWidget {
  const CommaGapDetector({
    required this.afterTokenIndex,
    required this.commaPlaced,
    required this.isFlashingWrong,
    required this.onTap,
    this.showDebugHitboxes = false,
    super.key,
  });

  final int afterTokenIndex;
  final bool commaPlaced;
  final bool isFlashingWrong;
  final ValueChanged<int> onTap;
  final bool showDebugHitboxes;

  @override
  Widget build(BuildContext context) {
    final bool debugVisible = kDebugMode && showDebugHitboxes;
    final Color borderColor = isFlashingWrong
        ? AppColors.error
        : commaPlaced
        ? AppColors.accent
        : debugVisible
        ? AppColors.reward.withValues(alpha: 0.65)
        : Colors.transparent;
    final Color fillColor = isFlashingWrong
        ? AppColors.error.withValues(alpha: 0.20)
        : debugVisible
        ? AppColors.reward.withValues(alpha: 0.10)
        : Colors.transparent;

    return Semantics(
      button: true,
      label: 'Gap after token $afterTokenIndex',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(afterTokenIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 28,
          height: 44,
          margin: const EdgeInsets.only(right: 2),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: AnimatedOpacity(
            opacity: commaPlaced ? 1 : 0,
            duration: const Duration(milliseconds: 140),
            child: Text(
              ',',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
