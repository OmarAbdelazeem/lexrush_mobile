import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class CommaGapDetector extends StatelessWidget {
  const CommaGapDetector({
    required this.afterTokenIndex,
    required this.isFlashingWrong,
    required this.onTap,
    this.showDebugHitboxes = false,
    this.width = 28,
    this.height = 40,
    super.key,
  });

  final int afterTokenIndex;
  final bool isFlashingWrong;
  final ValueChanged<int> onTap;
  final bool showDebugHitboxes;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool debugVisible = kDebugMode && showDebugHitboxes;
    final Color fillColor = debugVisible
        ? AppColors.reward.withValues(alpha: 0.12)
        : Colors.transparent;
    final Color borderColor = debugVisible
        ? AppColors.reward.withValues(alpha: 0.65)
        : Colors.transparent;

    return Semantics(
      button: true,
      label: 'Gap after token $afterTokenIndex',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(afterTokenIndex),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: isFlashingWrong
                      ? AppColors.error.withValues(alpha: 0.08)
                      : fillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
              ),
              AnimatedOpacity(
                opacity: isFlashingWrong ? 1 : 0,
                duration: const Duration(milliseconds: 90),
                child: Transform.translate(
                  offset: Offset(0, height * 0.24),
                  child: Container(
                    width: width.clamp(18, 30),
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.55),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
