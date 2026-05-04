import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/features/games/association/application/cubit/association_cubit.dart';
import 'package:lexrush/features/games/association/application/cubit/association_state.dart';
import 'package:lexrush/features/games/association/domain/entities/association_option.dart';
import 'package:lexrush/features/games/association/domain/entities/association_outcome.dart';
import 'package:lexrush/shared/presentation/widgets/combo_meter.dart';
import 'package:lexrush/shared/presentation/widgets/game_timer.dart';
import 'package:lexrush/shared/presentation/widgets/score_display.dart';

class AssociationScreen extends StatelessWidget {
  const AssociationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssociationCubit>(
      create: (_) => AssociationCubit()..start(),
      child: BlocConsumer<AssociationCubit, AssociationState>(
        listener: (BuildContext context, AssociationState state) {
          if (state.status == AssociationStatus.finished &&
              state.result != null) {
            debugPrint('[AssociationScreen] session ended -> go results');
            context.go(AppRoutes.results, extra: state.result);
          }
        },
        builder: (BuildContext context, AssociationState state) {
          final AssociationCubit cubit = context.read<AssociationCubit>();
          final List<AssociationOption> options =
              state.currentRound?.options ?? const <AssociationOption>[];
          final bool urgent = state.timeLeft <= 10;

          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Stack(
                    children: <Widget>[
                      if (urgent)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: <Color>[
                                    Colors.transparent,
                                    AppColors.error.withValues(alpha: 0.22),
                                  ],
                                  radius: 1.1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const _NeuralBackground(),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _Header(state: state, cubit: cubit),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                ScoreDisplay(score: state.score),
                                GameTimer(secondsLeft: state.timeLeft),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ComboMeter(combo: state.combo),
                            const SizedBox(height: 18),
                            Expanded(
                              child: _AssociationGraph(
                                state: state,
                                options: options,
                                onTap: cubit.submitAnswer,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FeedbackPanel(
                              state: state,
                              onContinue: cubit.continueAfterFeedback,
                            ),
                          ],
                        ),
                      ),
                      if (state.status == AssociationStatus.paused)
                        _PauseOverlay(cubit: cubit),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.cubit});

  final AssociationState state;
  final AssociationCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: state.status == AssociationStatus.paused
              ? cubit.resume
              : cubit.pause,
          icon: Icon(
            state.status == AssociationStatus.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
          ),
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Association',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Tap the closest match',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssociationGraph extends StatelessWidget {
  const _AssociationGraph({
    required this.state,
    required this.options,
    required this.onTap,
  });

  final AssociationState state;
  final List<AssociationOption> options;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final String target = state.currentRound?.targetWord ?? '...';
    final String? contextHint = state.currentRound?.contextHint;
    final AssociationOption? left = options.isNotEmpty ? options[0] : null;
    final AssociationOption? right = options.length > 1 ? options[1] : null;
    final int roundId = state.currentRound?.roundId ?? 0;
    final bool emphasizeInstruction = roundId > 0 && roundId <= 5;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Offset targetCenter = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight * 0.23,
        );
        final Offset leftCenter = Offset(
          constraints.maxWidth * 0.30,
          constraints.maxHeight * 0.61,
        );
        final Offset rightCenter = Offset(
          constraints.maxWidth * 0.70,
          constraints.maxHeight * 0.61,
        );

        return TweenAnimationBuilder<double>(
          key: ValueKey<int>(roundId),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double progress, Widget? child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.18),
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 18,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: emphasizeInstruction ? 1 : 0.72,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.accent.withValues(
                                alpha: emphasizeInstruction ? 0.42 : 0.18,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            child: Text(
                              'Tap the closest match',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: emphasizeInstruction ? 1 : 0.72,
                                    ),
                                    fontWeight: emphasizeInstruction
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LinkPainter(
                        target: targetCenter,
                        left: leftCenter,
                        right: rightCenter,
                        leftState: _lineStateFor(left, state),
                        rightState: _lineStateFor(right, state),
                        progress: progress,
                      ),
                    ),
                  ),
                  Positioned(
                    left: targetCenter.dx - 78,
                    top: targetCenter.dy - 74,
                    child: Transform.scale(
                      scale: 0.90 + (0.10 * progress),
                      child: Opacity(
                        opacity: progress,
                        child: _RootNode(
                          label: target.toUpperCase(),
                          contextHint: contextHint,
                          feedbackActive:
                              state.status == AssociationStatus.feedback,
                        ),
                      ),
                    ),
                  ),
                  if (state.status == AssociationStatus.feedback &&
                      state.lastOutcome == AssociationOutcome.correct)
                    Positioned(
                      left: targetCenter.dx + 28,
                      top: targetCenter.dy - 104,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        builder:
                            (
                              BuildContext context,
                              double value,
                              Widget? child,
                            ) {
                              return Opacity(
                                opacity: 1 - value,
                                child: Transform.translate(
                                  offset: Offset(0, -24 * value),
                                  child: child,
                                ),
                              );
                            },
                        child: Text(
                          '+100',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.reward,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ),
                  if (left != null)
                    Positioned(
                      left: leftCenter.dx - 82,
                      top: leftCenter.dy - 64,
                      child: Transform.scale(
                        scale: 0.85 + (0.15 * progress),
                        child: Opacity(
                          opacity: progress,
                          child: _OptionNode(
                            option: left,
                            state: state,
                            onTap: onTap,
                          ),
                        ),
                      ),
                    ),
                  if (right != null)
                    Positioned(
                      left: rightCenter.dx - 82,
                      top: rightCenter.dy - 64,
                      child: Transform.scale(
                        scale: 0.85 + (0.15 * progress),
                        child: Opacity(
                          opacity: progress,
                          child: _OptionNode(
                            option: right,
                            state: state,
                            onTap: onTap,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  _ConnectionState _lineStateFor(
    AssociationOption? option,
    AssociationState state,
  ) {
    if (option == null || state.status != AssociationStatus.feedback) {
      return _ConnectionState.idle;
    }
    if (option.isCorrect) {
      return _ConnectionState.correct;
    }
    if (state.selectedOptionId == option.id) {
      return _ConnectionState.wrong;
    }
    return _ConnectionState.idle;
  }
}

class _OptionNode extends StatelessWidget {
  const _OptionNode({
    required this.option,
    required this.state,
    required this.onTap,
  });

  final AssociationOption option;
  final AssociationState state;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final bool feedback = state.status == AssociationStatus.feedback;
    final bool selected = state.selectedOptionId == option.id;
    final bool revealCorrect = feedback && option.isCorrect;
    final bool revealWrong = feedback && selected && !option.isCorrect;
    final Color glowColor = revealCorrect
        ? AppColors.reward
        : revealWrong
        ? AppColors.error
        : AppColors.accent;
    final Color textColor = revealWrong
        ? AppColors.error
        : AppColors.textPrimary;
    final bool enabled = state.status == AssociationStatus.playing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onTap(option.id) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        scale: selected || revealCorrect ? 1.08 : 1,
        child: SizedBox(
          width: 164,
          height: 128,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  glowColor.withValues(
                    alpha: revealCorrect || revealWrong ? 0.30 : 0.14,
                  ),
                  AppColors.surface.withValues(alpha: 0.95),
                ],
              ),
              border: Border.all(
                color: glowColor.withValues(
                  alpha: revealCorrect || revealWrong ? 0.95 : 0.32,
                ),
                width: revealCorrect || revealWrong ? 3 : 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: glowColor.withValues(
                    alpha: revealCorrect || revealWrong ? 0.45 : 0.18,
                  ),
                  blurRadius: revealCorrect || revealWrong ? 28 : 16,
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      revealWrong
                          ? Icons.close_rounded
                          : revealCorrect
                          ? Icons.check_rounded
                          : Icons.bubble_chart_rounded,
                      color: glowColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option.word.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RootNode extends StatelessWidget {
  const _RootNode({
    required this.label,
    required this.contextHint,
    required this.feedbackActive,
  });

  final String label;
  final String? contextHint;
  final bool feedbackActive;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: feedbackActive ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.scale(
          scale: feedbackActive ? 1 + (0.03 * value) : 1,
          child: child,
        );
      },
      child: SizedBox(
        width: 156,
        height: 148,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                AppColors.primary.withValues(alpha: 0.56),
                AppColors.surface.withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.52),
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 34,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.hub_rounded,
                  color: AppColors.accent.withValues(alpha: 0.85),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                if (contextHint != null && contextHint!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    contextHint!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.state, required this.onContinue});

  final AssociationState state;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final bool visible = state.status == AssociationStatus.feedback;
    final AssociationOutcome? outcome = state.lastOutcome;
    final String title = switch (outcome) {
      AssociationOutcome.correct => '+100 Correct!',
      AssociationOutcome.wrong => 'Wrong -3s',
      AssociationOutcome.missed =>
        state.currentRound != null && state.currentRound!.roundId <= 5
            ? 'Missed'
            : 'Missed -2s',
      null => '',
    };
    final String explanation = state.currentRound?.explanation ?? '';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: visible
          ? GestureDetector(
              key: ValueKey<String>('feedback-${state.currentRound?.roundId}'),
              behavior: HitTestBehavior.opaque,
              onTap: onContinue,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _outcomeColor(outcome).withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _outcomeColor(outcome),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      explanation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to continue',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(height: 92),
    );
  }

  Color _outcomeColor(AssociationOutcome? outcome) {
    return switch (outcome) {
      AssociationOutcome.correct => AppColors.reward,
      AssociationOutcome.wrong => AppColors.error,
      AssociationOutcome.missed => AppColors.accent,
      null => AppColors.accent,
    };
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.cubit});

  final AssociationCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.82),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Paused',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: cubit.resume,
                  child: const Text('Resume'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ConnectionState { idle, correct, wrong }

class _LinkPainter extends CustomPainter {
  const _LinkPainter({
    required this.target,
    required this.left,
    required this.right,
    required this.leftState,
    required this.rightState,
    required this.progress,
  });

  final Offset target;
  final Offset left;
  final Offset right;
  final _ConnectionState leftState;
  final _ConnectionState rightState;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    _drawConnection(canvas, target, left, leftState);
    _drawConnection(canvas, target, right, rightState);
  }

  void _drawConnection(
    Canvas canvas,
    Offset start,
    Offset end,
    _ConnectionState state,
  ) {
    final Color color = switch (state) {
      _ConnectionState.correct => AppColors.reward,
      _ConnectionState.wrong => AppColors.error,
      _ConnectionState.idle => AppColors.accent,
    };
    final Paint glow = Paint()
      ..color = color.withValues(
        alpha: state == _ConnectionState.idle ? 0.10 : 0.35,
      )
      ..strokeWidth = state == _ConnectionState.idle ? 12 : 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint line = Paint()
      ..color = color.withValues(
        alpha: state == _ConnectionState.idle ? 0.34 : 0.95,
      )
      ..strokeWidth = state == _ConnectionState.idle ? 2 : 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Path path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        (start.dx + end.dx) / 2,
        math.min(start.dy, end.dy) + 70,
        end.dx,
        end.dy,
      );
    final PathMetric metric = path.computeMetrics().first;
    final Path visiblePath = metric.extractPath(0, metric.length * progress);
    canvas
      ..drawPath(visiblePath, glow)
      ..drawPath(visiblePath, line);
    if (state == _ConnectionState.correct && progress >= 1) {
      final Tangent? tangent = metric.getTangentForOffset(metric.length * 0.64);
      if (tangent != null) {
        final Paint particle = Paint()
          ..color = AppColors.reward.withValues(alpha: 0.82)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, 5, particle);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinkPainter oldDelegate) {
    return target != oldDelegate.target ||
        left != oldDelegate.left ||
        right != oldDelegate.right ||
        leftState != oldDelegate.leftState ||
        rightState != oldDelegate.rightState ||
        progress != oldDelegate.progress;
  }
}

class _NeuralBackground extends StatelessWidget {
  const _NeuralBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _NeuralBackgroundPainter()),
      ),
    );
  }
}

class _NeuralBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint dotPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final Paint linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final List<Offset> points = <Offset>[
      Offset(size.width * 0.12, size.height * 0.18),
      Offset(size.width * 0.36, size.height * 0.11),
      Offset(size.width * 0.78, size.height * 0.20),
      Offset(size.width * 0.16, size.height * 0.50),
      Offset(size.width * 0.86, size.height * 0.48),
      Offset(size.width * 0.30, size.height * 0.84),
      Offset(size.width * 0.72, size.height * 0.82),
    ];

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }
    for (final Offset point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
