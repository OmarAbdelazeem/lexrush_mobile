import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart';
import 'package:lexrush/features/games/antonym_rush/application/cubit/antonym_rush_state.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/balloon_option.dart';
import 'package:lexrush/shared/presentation/widgets/combo_meter.dart';
import 'package:lexrush/shared/presentation/widgets/game_timer.dart';
import 'package:lexrush/shared/presentation/widgets/score_display.dart';

class AntonymRushScreen extends StatefulWidget {
  const AntonymRushScreen({
    this.gameTitle = 'Gameplay',
    this.promptLabel = 'Find opposite',
    super.key,
  });

  final String gameTitle;
  final String promptLabel;

  @override
  State<AntonymRushScreen> createState() => _AntonymRushScreenState();
}

class _AntonymRushScreenState extends State<AntonymRushScreen> {
  final Map<String, bool> _visibilityByOption = <String, bool>{};
  Timer? _deadframeGuardTimer;
  Timer? _feedbackLatchTimer;
  String? _latchedFeedbackText;
  RoundOutcome? _latchedFeedbackOutcome;

  @override
  void dispose() {
    _deadframeGuardTimer?.cancel();
    _feedbackLatchTimer?.cancel();
    super.dispose();
  }

  void _onOptionVisibilityChanged(
    String optionId,
    bool isVisible, {
    required AntonymRushState state,
    required AntonymRushCubit cubit,
  }) {
    _visibilityByOption[optionId] = isVisible;
    _evaluateDeadframeGuard(state: state, cubit: cubit);
  }

  void _evaluateDeadframeGuard({
    required AntonymRushState state,
    required AntonymRushCubit cubit,
  }) {
    final List<BalloonOption> options =
        state.currentRound?.options ?? const <BalloonOption>[];
    if (state.status != AntonymRushStatus.playing || options.isEmpty) {
      _deadframeGuardTimer?.cancel();
      _deadframeGuardTimer = null;
      return;
    }

    final bool anyVisible = options.any(
      (BalloonOption option) => _visibilityByOption[option.id] == true,
    );
    if (anyVisible) {
      _deadframeGuardTimer?.cancel();
      _deadframeGuardTimer = null;
      return;
    }

    _deadframeGuardTimer ??= Timer(const Duration(milliseconds: 1050), () {
      _deadframeGuardTimer = null;
      final AntonymRushState latest = cubit.state;
      final List<BalloonOption> latestOptions =
          latest.currentRound?.options ?? const <BalloonOption>[];
      final bool latestAnyVisible = latestOptions.any(
        (BalloonOption option) => _visibilityByOption[option.id] == true,
      );
      if (latest.status == AntonymRushStatus.playing &&
          latestOptions.isNotEmpty &&
          !latestAnyVisible) {
        debugPrint(
          '[AntonymRushScreen] deadframe guard -> registerMissedRound',
        );
        cubit.registerMissedRound(reason: MissedReason.watchdog);
      }
    });
  }

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
          final List<BalloonOption> options =
              state.currentRound?.options ?? const <BalloonOption>[];
          if (state.feedbackText != null &&
              state.feedbackText != _latchedFeedbackText) {
            _feedbackLatchTimer?.cancel();
            _latchedFeedbackText = state.feedbackText;
            _latchedFeedbackOutcome = state.lastOutcome;
            _feedbackLatchTimer = Timer(const Duration(milliseconds: 520), () {
              if (!mounted) return;
              setState(() {
                _latchedFeedbackText = null;
                _latchedFeedbackOutcome = null;
              });
            });
          }
          final String? visibleFeedbackText =
              state.feedbackText ?? _latchedFeedbackText;
          final RoundOutcome? visibleFeedbackOutcome =
              state.feedbackText != null
              ? state.lastOutcome
              : _latchedFeedbackOutcome;
          _visibilityByOption.removeWhere(
            (String key, bool value) => !options.any((o) => o.id == key),
          );
          _evaluateDeadframeGuard(state: state, cubit: cubit);
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
                            child: AnimatedOpacity(
                              opacity: 1,
                              duration: const Duration(milliseconds: 300),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: <Color>[
                                      Colors.transparent,
                                      AppColors.error.withValues(alpha: 0.25),
                                    ],
                                    radius: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const _BackgroundLetters(),
                      Positioned(
                        top: 108,
                        left: 10,
                        right: 10,
                        bottom: 152,
                        child: LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: options
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                        final int index = entry.key;
                                        final BalloonOption option =
                                            entry.value;
                                        return _BalloonChoice(
                                          key: ValueKey<String>(
                                            '${state.currentRound?.roundId}-${option.id}',
                                          ),
                                          option: option,
                                          roundId:
                                              state.currentRound?.roundId ?? 0,
                                          laneIndex: index,
                                          roundSpeedSeconds: state.currentSpeed,
                                          escaped: state.escapedOptionIds
                                              .contains(option.id),
                                          enabled:
                                              state.status ==
                                              AntonymRushStatus.playing,
                                          playfieldWidth: constraints.maxWidth,
                                          playfieldHeight:
                                              constraints.maxHeight,
                                          onTap: () =>
                                              cubit.submitAnswer(option.id),
                                          onEscaped: () =>
                                              cubit.onBalloonEscaped(option.id),
                                          onVisibilityChanged:
                                              (String id, bool visible) {
                                                _onOptionVisibilityChanged(
                                                  id,
                                                  visible,
                                                  state: state,
                                                  cubit: cubit,
                                                );
                                              },
                                        );
                                      })
                                      .toList(growable: false),
                                );
                              },
                        ),
                      ),
                      Positioned(
                        top: 18,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: <Widget>[
                            _CircleIconButton(
                              icon: Icons.pause_rounded,
                              onTap: cubit.pause,
                            ),
                            const Spacer(),
                            GameTimer(secondsLeft: state.timeLeft),
                            const SizedBox(width: 10),
                            ScoreDisplay(score: state.score),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 108,
                        left: 20,
                        right: 20,
                        child: _TargetWordCard(
                          promptLabel: widget.promptLabel,
                          target: target,
                        ),
                      ),
                      if (visibleFeedbackText != null)
                        Positioned(
                          top: 304,
                          left: 26,
                          right: 26,
                          child: IgnorePointer(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              reverseDuration: const Duration(
                                milliseconds: 180,
                              ),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    final Animation<double> slide =
                                        Tween<double>(
                                          begin: 10,
                                          end: 0,
                                        ).animate(animation);
                                    return FadeTransition(
                                      opacity: animation,
                                      child: AnimatedBuilder(
                                        animation: animation,
                                        builder:
                                            (BuildContext context, Widget? _) {
                                              final double scale =
                                                  0.93 +
                                                  (0.07 * animation.value);
                                              return Transform.translate(
                                                offset: Offset(0, -slide.value),
                                                child: Transform.scale(
                                                  scale: scale,
                                                  child: child,
                                                ),
                                              );
                                            },
                                      ),
                                    );
                                  },
                              child: Container(
                                key: ValueKey<String>(visibleFeedbackText),
                                alignment: Alignment.center,
                                constraints: const BoxConstraints(
                                  minHeight: 42,
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 82,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        (visibleFeedbackOutcome ==
                                                    RoundOutcome.wrong
                                                ? AppColors.error
                                                : visibleFeedbackOutcome ==
                                                      RoundOutcome.missed
                                                ? AppColors.reward
                                                : AppColors.accent)
                                            .withValues(alpha: 0.7),
                                  ),
                                  boxShadow: const <BoxShadow>[
                                    BoxShadow(
                                      blurRadius: 14,
                                      color: Colors.black54,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  visibleFeedbackText,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color:
                                            visibleFeedbackOutcome ==
                                                RoundOutcome.wrong
                                            ? AppColors.error
                                            : visibleFeedbackOutcome ==
                                                  RoundOutcome.missed
                                            ? AppColors.reward
                                            : AppColors.accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 24,
                                        letterSpacing: 0.2,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 18,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ComboMeter(combo: state.combo),
                            const SizedBox(height: 6),
                            Text(
                              'Words: ${state.wordsSolved}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (state.status == AntonymRushStatus.paused)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.74),
                            child: Center(
                              child: Container(
                                width: 300,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'Paused',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: cubit.resume,
                                        child: const Text('Resume'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: cubit.restart,
                                        child: const Text('Restart'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: cubit.endGame,
                                        child: const Text('End Session'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 20,
                        right: 90,
                        child: Text(
                          widget.gameTitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
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

class _BackgroundLetters extends StatelessWidget {
  const _BackgroundLetters();

  @override
  Widget build(BuildContext context) {
    final List<String> letters = <String>['L', 'E', 'X', 'R', 'U', 'S', 'H'];
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.04,
          child: Stack(
            children: List<Widget>.generate(letters.length, (int index) {
              return Positioned(
                left: 16 + (index * 55),
                top: 140 + ((index % 3) * 110),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 3400 + (index * 300)),
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, -10 * value),
                    child: child,
                  ),
                  child: Text(
                    letters[index],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 56,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _TargetWordCard extends StatelessWidget {
  const _TargetWordCard({required this.promptLabel, required this.target});

  final String promptLabel;
  final String target;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF5951EE), Color(0xFF28C7EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 26,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.20),
            blurRadius: 40,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          children: <Widget>[
            Container(
              height: 4,
              width: 88,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              promptLabel.toUpperCase(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              target,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontSize: 43,
                fontWeight: FontWeight.w700,
                shadows: const <Shadow>[
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black26,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalloonChoice extends StatefulWidget {
  const _BalloonChoice({
    required this.option,
    required this.roundId,
    required this.laneIndex,
    required this.roundSpeedSeconds,
    required this.escaped,
    required this.enabled,
    required this.playfieldWidth,
    required this.playfieldHeight,
    required this.onTap,
    required this.onEscaped,
    required this.onVisibilityChanged,
    super.key,
  });

  final BalloonOption option;
  final int roundId;
  final int laneIndex;
  final double roundSpeedSeconds;
  final bool escaped;
  final bool enabled;
  final double playfieldWidth;
  final double playfieldHeight;
  final VoidCallback onTap;
  final VoidCallback onEscaped;
  final void Function(String optionId, bool isVisible) onVisibilityChanged;

  @override
  State<_BalloonChoice> createState() => _BalloonChoiceState();
}

class _BalloonChoiceState extends State<_BalloonChoice>
    with SingleTickerProviderStateMixin {
  static const double _balloonWidth = 104;
  static const double _balloonHeight = 152;
  static const List<List<int>> _lanePatterns = <List<int>>[
    <int>[0, 2, 1, 3],
    <int>[1, 3, 0, 2],
    <int>[2, 0, 3, 1],
    <int>[3, 1, 2, 0],
  ];
  static const List<double> _laneAnchors = <double>[0.11, 0.34, 0.63, 0.86];
  static const List<double> _verticalOffsets = <double>[
    -0.030,
    0.008,
    -0.014,
    0.022,
  ];
  late final AnimationController _controller;
  bool _lastVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (widget.roundSpeedSeconds * 1000).round(),
      ),
    )..addStatusListener(_onMainStatusChanged);
    if (widget.enabled && !widget.escaped) {
      _controller.forward();
    }
  }

  void _onMainStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        widget.enabled &&
        !widget.escaped) {
      widget.onEscaped();
    }
  }

  @override
  void didUpdateWidget(covariant _BalloonChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.option.id != widget.option.id) {
      _lastVisible = false;
      _controller
        ..duration = Duration(
          milliseconds: (widget.roundSpeedSeconds * 1000).round(),
        )
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
    if (widget.enabled &&
        !_controller.isAnimating &&
        _controller.status != AnimationStatus.completed) {
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
    final List<int> lanePattern =
        _lanePatterns[widget.roundId % _lanePatterns.length];
    final int laneSlot = lanePattern[widget.laneIndex % lanePattern.length];
    final double laneJitter =
        (((widget.roundId * 11) + (widget.laneIndex * 17)) % 9 - 4) * 0.003;
    final double lane = (_laneAnchors[laneSlot] + laneJitter).clamp(0.08, 0.90);
    final double verticalJitter =
        (((widget.roundId * 13) + (widget.laneIndex * 19)) % 7 - 3) * 0.006;
    final double verticalOffset = (_verticalOffsets[laneSlot] + verticalJitter)
        .clamp(-0.045, 0.035);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double left =
            (widget.playfieldWidth * lane).clamp(
              12 + (_balloonWidth / 2),
              widget.playfieldWidth - 12 - (_balloonWidth / 2),
            ) -
            (_balloonWidth / 2);
        const double escapeTop = 16;
        final double spawnTop =
            widget.playfieldHeight -
            _balloonHeight -
            12 +
            (widget.playfieldHeight * verticalOffset);
        final double top = lerpDouble(
          spawnTop,
          escapeTop,
          _controller.value,
        )!.clamp(escapeTop, widget.playfieldHeight - _balloonHeight - 12);
        final bool isVisible =
            !widget.escaped &&
            top < (widget.playfieldHeight - 6) &&
            (top + _balloonHeight) > 6;
        if (isVisible != _lastVisible) {
          _lastVisible = isVisible;
          widget.onVisibilityChanged(widget.option.id, isVisible);
        }
        return Positioned(
          left: left,
          top: top,
          child: Opacity(opacity: widget.escaped ? 0 : 1, child: child),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled && !widget.escaped ? widget.onTap : null,
        child: SizedBox(
          width: _balloonWidth,
          height: _balloonHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: <Widget>[
              Positioned(
                top: 8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 98,
                  height: 116,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: _balloonGradient(widget.option.word),
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(56, 64),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _balloonColor(
                          widget.option.word,
                        ).withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.option.word,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: _fontSizeForWord(widget.option.word),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                left: 22,
                child: Container(
                  width: 22,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Positioned(
                top: 121,
                child: Container(
                  width: 10,
                  height: 11,
                  decoration: BoxDecoration(
                    color: _balloonColor(widget.option.word),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 130,
                child: Container(
                  width: 1.4,
                  height: 24,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _balloonColor(String word) {
    const List<Color> palette = <Color>[
      Color(0xFF4F46E5),
      Color(0xFF22D3EE),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
    ];
    return palette[word.codeUnitAt(0).abs() % palette.length];
  }

  LinearGradient _balloonGradient(String word) {
    final Color base = _balloonColor(word);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        base.withValues(alpha: 0.95),
        Color.lerp(base, Colors.white, 0.18)!,
      ],
    );
  }

  double _fontSizeForWord(String word) {
    final int len = word.length;
    if (len >= 10) return 14.8;
    if (len >= 8) return 16.0;
    return 17.2;
  }
}
