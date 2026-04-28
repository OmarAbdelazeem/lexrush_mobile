import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_state.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/balloon_option.dart';
import 'package:lexrush/shared/presentation/widgets/combo_meter.dart';
import 'package:lexrush/shared/presentation/widgets/game_shell.dart';
import 'package:lexrush/shared/presentation/widgets/game_timer.dart';
import 'package:lexrush/shared/presentation/widgets/primary_button.dart';
import 'package:lexrush/shared/presentation/widgets/score_display.dart';

class AntonymRushScreen extends StatelessWidget {
  const AntonymRushScreen({
    this.gameTitle = 'Gameplay',
    this.promptLabel = 'Find opposite',
    super.key,
  });

  final String gameTitle;
  final String promptLabel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AntonymRushCubit>(
      create: (_) => AntonymRushCubit()..start(),
      child: BlocConsumer<AntonymRushCubit, AntonymRushState>(
        listener: (BuildContext context, AntonymRushState state) {
          if (state.status == AntonymRushStatus.ended) {
            debugPrint('[AntonymRushScreen] session ended -> go results');
            context.go(AppRoutes.results, extra: state.gameResult);
          }
        },
        builder: (BuildContext context, AntonymRushState state) {
          final AntonymRushCubit cubit = context.read<AntonymRushCubit>();
          final String target = state.currentRound?.targetWord ?? '...';
          final List<BalloonOption> options = state.currentRound?.options ?? const <BalloonOption>[];
          final bool urgent = state.timeLeft <= 10;
          return GameShell(
            title: gameTitle,
            hud: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                GameTimer(secondsLeft: state.timeLeft),
                ScoreDisplay(score: state.score),
              ],
            ),
            playfield: Stack(
              children: <Widget>[
                if (urgent)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        color: AppColors.error.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        promptLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        target,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Stack(
                          children: options.asMap().entries.map((entry) {
                            final int index = entry.key;
                            final BalloonOption option = entry.value;
                            return _BalloonChoice(
                              key: ValueKey<String>(
                                '${state.currentRound?.roundId}-${option.id}',
                              ),
                              option: option,
                              laneIndex: index,
                              roundSpeedSeconds: state.currentSpeed,
                              escaped: state.escapedOptionIds.contains(option.id),
                              enabled: state.status == AntonymRushStatus.playing,
                              onTap: () => cubit.submitAnswer(option.id),
                              onEscaped: () => cubit.onBalloonEscaped(option.id),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (state.feedbackText != null)
                        Text(
                          state.feedbackText!,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: state.lastOutcome == RoundOutcome.wrong
                                    ? AppColors.error
                                    : state.lastOutcome == RoundOutcome.missed
                                        ? AppColors.reward
                                        : AppColors.accent,
                              ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                if (state.status == AntonymRushStatus.paused)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          'Paused',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            footer: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ComboMeter(combo: state.combo),
                const SizedBox(height: 10),
                if (state.status == AntonymRushStatus.paused)
                  PrimaryButton(
                    label: 'Resume',
                    onPressed: cubit.resume,
                  )
                else
                  PrimaryButton(
                    label: 'Pause',
                    onPressed: cubit.pause,
                  ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'End Session',
                  onPressed: cubit.endGame,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: cubit.restart,
                  child: const Text('Restart'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalloonChoice extends StatefulWidget {
  const _BalloonChoice({
    required this.option,
    required this.laneIndex,
    required this.roundSpeedSeconds,
    required this.escaped,
    required this.enabled,
    required this.onTap,
    required this.onEscaped,
    super.key,
  });

  final BalloonOption option;
  final int laneIndex;
  final double roundSpeedSeconds;
  final bool escaped;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onEscaped;

  @override
  State<_BalloonChoice> createState() => _BalloonChoiceState();
}

class _BalloonChoiceState extends State<_BalloonChoice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _escapeNotified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.roundSpeedSeconds * 1000).round()),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && !_escapeNotified && !widget.escaped) {
          _escapeNotified = true;
          widget.onEscaped();
        }
      });
    if (widget.enabled && !widget.escaped) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _BalloonChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.option.id != widget.option.id) {
      _escapeNotified = false;
      _controller
        ..duration = Duration(milliseconds: (widget.roundSpeedSeconds * 1000).round())
        ..reset();
      if (widget.enabled && !widget.escaped) {
        _controller.forward();
      }
      return;
    }
    if (widget.escaped) {
      _controller.stop();
      return;
    }
    if (widget.enabled && !_controller.isAnimating) {
      _controller.forward();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const List<double> lanes = <double>[0.08, 0.32, 0.56, 0.80];
    final double lane = lanes[widget.laneIndex % lanes.length];
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double topFactor = 0.95 + (-1.10 * _controller.value);
        return Positioned(
          left: MediaQuery.sizeOf(context).width * lane - 55,
          top: (MediaQuery.sizeOf(context).height * 0.48 * topFactor) + 120,
          child: Opacity(
            opacity: widget.escaped ? 0 : 1,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 110,
        height: 68,
        child: ElevatedButton(
          onPressed: widget.enabled && !widget.escaped ? widget.onTap : null,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          child: Text(
            widget.option.word,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
