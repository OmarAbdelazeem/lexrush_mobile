import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/games/commas/application/cubit/commas_cubit.dart';
import 'package:lexrush/features/games/commas/application/cubit/commas_state.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';
import 'package:lexrush/features/games/commas/presentation/widgets/comma_feedback.dart';
import 'package:lexrush/features/games/commas/presentation/widgets/comma_text_area.dart';

class CommasScreen extends StatefulWidget {
  const CommasScreen({super.key});

  static const bool showDebugGapHitboxes = false;

  @override
  State<CommasScreen> createState() => _CommasScreenState();
}

class _CommasScreenState extends State<CommasScreen> {
  bool _navigatedToResults = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommasCubit>(
      create: (_) => CommasCubit()..start(),
      child: BlocConsumer<CommasCubit, CommasState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.result != current.result,
        listener: (context, state) {
          if (_navigatedToResults || state.status != CommasStatus.completed) {
            return;
          }
          final result = state.result;
          if (result == null) return;
          _navigatedToResults = true;
          context.go(AppRoutes.results, extra: result);
        },
        builder: (context, state) {
          return PortraitShell(
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Header(state: state),
                      const SizedBox(height: 12),
                      _Hud(state: state),
                      const SizedBox(height: 8),
                      if (state.tokens.isEmpty)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Expanded(
                          child: _PromptStage(
                            state: state,
                            onGapTap: context.read<CommasCubit>().submitGap,
                            helperText: _helperText(state.remainingCommaCount),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap the spaces where a comma is missing.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w800,
                          height: 1.24,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.status == CommasStatus.paused)
                  _PausedOverlay(onResume: context.read<CommasCubit>().resume),
              ],
            ),
          );
        },
      ),
    );
  }

  String _helperText(int remaining) {
    if (remaining == 1) return 'One comma left';
    if (remaining > 1) return '$remaining commas left';
    return 'Tap the spaces where commas are missing.';
  }
}

class _PromptStage extends StatelessWidget {
  const _PromptStage({
    required this.state,
    required this.onGapTap,
    required this.helperText,
  });

  final CommasState state;
  final ValueChanged<int> onGapTap;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    final CommaDifficulty difficulty =
        state.currentPrompt?.difficulty ?? CommaDifficulty.medium;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                CommaTextArea(
                  tokens: state.tokens,
                  flashGapAfterTokenIndex: state.flashGapAfterTokenIndex,
                  sentenceCompletePulse:
                      state.status == CommasStatus.sentenceComplete,
                  difficulty: difficulty,
                  showDebugGapHitboxes: CommasScreen.showDebugGapHitboxes,
                  onGapTap: onGapTap,
                ),
                const SizedBox(height: 8),
                Text(
                  helperText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                CommaFeedback(
                  status: state.status,
                  feedbackText: state.feedbackText,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final CommasState state;

  @override
  Widget build(BuildContext context) {
    final bool paused = state.status == CommasStatus.paused;
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () {
            final CommasCubit cubit = context.read<CommasCubit>();
            paused ? cubit.resume() : cubit.pause();
          },
          icon: Icon(
            paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Commas', style: Theme.of(context).textTheme.headlineSmall),
              Text(
                'Tap gaps. Restore clarity.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.state});

  final CommasState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _HudTile(label: 'Score', value: '${state.score}'),
        const SizedBox(width: 10),
        _HudTile(label: 'Left', value: '${state.remainingCommaCount}'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: state.timeLeft <= 10
                ? AppColors.error.withValues(alpha: 0.16)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: state.timeLeft <= 10
                  ? AppColors.error.withValues(alpha: 0.48)
                  : AppColors.accent.withValues(alpha: 0.26),
            ),
          ),
          child: Text(
            '0:${state.timeLeft.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: state.timeLeft <= 10 ? AppColors.error : AppColors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _HudTile extends StatelessWidget {
  const _HudTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.58)),
        child: Center(
          child: ElevatedButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume'),
          ),
        ),
      ),
    );
  }
}
