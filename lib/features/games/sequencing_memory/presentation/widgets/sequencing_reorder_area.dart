import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class SequencingReorderArea extends StatelessWidget {
  const SequencingReorderArea({
    required this.cards,
    required this.onReorder,
    super.key,
  });

  final List<String> cards;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? _) {
            final double value = Curves.easeOut.transform(animation.value);
            return Transform.scale(
              scale: 1 + (value * 0.025),
              child: Material(
                color: Colors.transparent,
                elevation: 12 * value,
                child: child,
              ),
            );
          },
        );
      },
      itemCount: cards.length,
      onReorder: onReorder,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          key: ValueKey<String>(cards[index]),
          padding: const EdgeInsets.only(bottom: 10),
          child: _SequenceCard(index: index, text: cards[index]),
        );
      },
    );
  }
}

class _SequenceCard extends StatelessWidget {
  const _SequenceCard({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.surface,
            AppColors.accent,
            index == 0 ? 0.16 : 0.07,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: index == 0
                ? AppColors.accent.withValues(alpha: 0.44)
                : AppColors.primary.withValues(alpha: 0.22),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.background.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.drag_indicator_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
