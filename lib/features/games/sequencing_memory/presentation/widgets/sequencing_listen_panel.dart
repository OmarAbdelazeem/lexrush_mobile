import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class SequencingListenPanel extends StatefulWidget {
  const SequencingListenPanel({
    required this.itemCount,
    required this.spokenProgress,
    required this.label,
    required this.currentSpokenItem,
    this.showDebugSpokenCaption = false,
    super.key,
  });

  final int itemCount;
  final int spokenProgress;
  final String label;
  final String? currentSpokenItem;
  final bool showDebugSpokenCaption;

  @override
  State<SequencingListenPanel> createState() => _SequencingListenPanelState();
}

class _SequencingListenPanelState extends State<SequencingListenPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.volume_up_rounded, color: AppColors.accent, size: 48),
            const SizedBox(height: 14),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Listen carefully. You will arrange the steps next.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Text(
              'Step ${_visibleStep()} of ${widget.itemCount}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.showDebugSpokenCaption &&
                widget.currentSpokenItem != null) ...<Widget>[
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    widget.currentSpokenItem!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? _) {
                  return CustomPaint(
                    painter: _WaveformPainter(progress: _controller.value),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(widget.itemCount, (int index) {
                final bool active = index < widget.spokenProgress;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 22 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accent
                        : AppColors.textSecondary.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  int _visibleStep() {
    if (widget.itemCount == 0) {
      return 0;
    }
    final int step = widget.spokenProgress + 1;
    return step.clamp(1, widget.itemCount);
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.72)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    final int bars = 13;
    final double gap = size.width / bars;
    for (int i = 0; i < bars; i += 1) {
      final double wave = math.sin((progress * math.pi * 2) + (i * 0.72));
      final double height = 12 + ((wave + 1) * 16);
      final double x = (gap * i) + (gap / 2);
      final double y = size.height / 2;
      canvas.drawLine(
        Offset(x, y - height / 2),
        Offset(x, y + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
