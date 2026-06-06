import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/games/sequencing_memory/application/cubit/sequencing_memory_cubit.dart';
import 'package:lexrush/features/games/sequencing_memory/application/cubit/sequencing_memory_state.dart';
import 'package:lexrush/features/games/sequencing_memory/application/services/sequencing_memory_backend_bootstrap.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_round_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_stage.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/services/sequencing_audio_service.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/services/sequencing_round_generator.dart';
import 'package:lexrush/features/games/sequencing_memory/presentation/widgets/sequencing_listen_panel.dart';
import 'package:lexrush/features/games/sequencing_memory/presentation/widgets/sequencing_reorder_area.dart';
import 'package:lexrush/features/games/sequencing_memory/presentation/widgets/sequencing_route_background.dart';
import 'package:lexrush/shared/application/services/backend_result_mappers.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';
import 'package:lexrush/shared/domain/contracts/crash_reporter.dart';
import 'package:lexrush/shared/domain/entities/synced_result_extra.dart';
import 'package:lexrush/shared/presentation/widgets/primary_button.dart';
import 'package:lexrush/shared/presentation/widgets/score_display.dart';

class SequencingMemoryScreen extends StatefulWidget {
  const SequencingMemoryScreen({super.key});

  static const bool showDebugSpokenCaption = kDebugMode;

  @override
  State<SequencingMemoryScreen> createState() => _SequencingMemoryScreenState();
}

class _SequencingMemoryScreenState extends State<SequencingMemoryScreen> {
  Future<SequencingMemoryBootstrapResult>? _bootstrapFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapFuture != null) return;
    _bootstrapFuture = SequencingMemoryBackendBootstrap(
      repository: context.read<LexRushBackendRepository>(),
      pendingQueue: context.read<PendingResultQueue>(),
      userId: context.read<AuthCubit>().state.user?.userId,
      analytics: context.read<AnalyticsPort>(),
    ).load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SequencingMemoryBootstrapResult>(
      future: _bootstrapFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<SequencingMemoryBootstrapResult> snapshot,
      ) {
        if (!snapshot.hasData) {
          return const PortraitShell(
            child: Center(child: Text('Preparing Sequencing Memory…')),
          );
        }
        return _SequencingMemoryGameplay(bootstrap: snapshot.requireData);
      },
    );
  }
}

class _SequencingMemoryGameplay extends StatefulWidget {
  const _SequencingMemoryGameplay({required this.bootstrap});

  final SequencingMemoryBootstrapResult bootstrap;

  @override
  State<_SequencingMemoryGameplay> createState() =>
      _SequencingMemoryGameplayState();
}

class _SequencingMemoryGameplayState extends State<_SequencingMemoryGameplay> {
  bool _navigatedToResults = false;
  BackendResultSyncService? _resultSyncService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.bootstrap.createResultSyncOnFinish ||
        _resultSyncService != null) {
      return;
    }
    _resultSyncService = BackendResultSyncService(
      gameId: BackendGameIds.sequencingMemory,
      repository: context.read<LexRushBackendRepository>(),
      pendingQueue: context.read<PendingResultQueue>(),
      userId: context.read<AuthCubit>().state.user?.userId,
      analytics: context.read<AnalyticsPort>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SequencingMemoryCubit>(
      create: (_) => SequencingMemoryCubit(
        audioService: DeviceTtsSequencingAudioService(),
        roundGenerator: SequencingRoundGenerator(
          prompts: widget.bootstrap.prompts,
          preservePromptOrder: widget.bootstrap.usedBackendPrompts,
        ),
        analytics: context.read<AnalyticsPort>(),
        crashReporter: context.read<CrashReporter>(),
        usedBackendPrompts: widget.bootstrap.usedBackendPrompts,
      )..start(),
      child: BlocConsumer<SequencingMemoryCubit, SequencingMemoryState>(
        listener: (BuildContext context, SequencingMemoryState state) {
          if (!_navigatedToResults &&
              state.stage == SequencingStage.finished &&
              state.result != null) {
            debugPrint('[SequencingMemoryScreen] session ended -> go results');
            _navigatedToResults = true;
            final BackendResultSyncHandle? syncHandle =
                widget.bootstrap.syncService?.submitSummaryWithHandle(
                  BackendResultMappers.sequencingMemory(state.result!),
                ) ??
                _resultSyncService?.submitSummaryWithHandle(
                  BackendResultMappers.sequencingMemory(state.result!),
                ) ??
                _fallbackSyncHandle(widget.bootstrap.fallbackSyncStatus);
            context.go(
              AppRoutes.results,
              extra: syncHandle == null
                  ? state.result
                  : SyncedResultExtra(
                      result: state.result!,
                      syncHandle: syncHandle,
                    ),
            );
          }
        },
        builder: (BuildContext context, SequencingMemoryState state) {
          final SequencingMemoryCubit cubit = context
              .read<SequencingMemoryCubit>();
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Stack(
                    children: <Widget>[
                      const SequencingRouteBackground(),
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
                                _ChallengeCounter(state: state),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _StageBanner(state: state),
                            const SizedBox(height: 14),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                child: _StageBody(
                                  key: ValueKey<SequencingStage>(state.stage),
                                  state: state,
                                  cubit: cubit,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.stage == SequencingStage.paused)
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

  BackendResultSyncHandle? _fallbackSyncHandle(BackendSyncStatus? status) {
    if (status == null) return null;
    final BackendResultSyncHandle handle = BackendResultSyncHandle();
    handle.setStatus(status);
    handle.complete();
    return handle;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.cubit});

  final SequencingMemoryState state;
  final SequencingMemoryCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: state.stage == SequencingStage.paused
              ? cubit.resume
              : cubit.pause,
          icon: Icon(
            state.stage == SequencingStage.paused
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
                'Sequencing Memory',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Listen, arrange, combine',
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

class _ChallengeCounter extends StatelessWidget {
  const _ChallengeCounter({required this.state});

  final SequencingMemoryState state;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          'Route ${state.currentChallengeIndex}/${state.totalChallenges}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.state});

  final SequencingMemoryState state;

  @override
  Widget build(BuildContext context) {
    final bool combined = state.stage.isCombined;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (combined ? AppColors.reward : AppColors.primary).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (combined ? AppColors.reward : AppColors.primary).withValues(
            alpha: 0.28,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(
              combined ? Icons.workspace_premium_rounded : Icons.route_rounded,
              color: combined ? AppColors.reward : AppColors.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _stageTitle(state.stage),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: combined ? AppColors.reward : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageBody extends StatelessWidget {
  const _StageBody({required this.state, required this.cubit, super.key});

  final SequencingMemoryState state;
  final SequencingMemoryCubit cubit;

  @override
  Widget build(BuildContext context) {
    if (state.stage.isListening) {
      return Column(
        key: const ValueKey<String>('listen'),
        children: <Widget>[
          Expanded(
            child: SequencingListenPanel(
              itemCount: state.currentItems.length,
              spokenProgress: state.spokenProgress,
              label: _listenLabel(state.stage),
              currentSpokenItem: state.currentSpokenItem,
              showDebugSpokenCaption:
                  SequencingMemoryScreen.showDebugSpokenCaption,
            ),
          ),
        ],
      );
    }
    if (state.stage.isArranging) {
      return Column(
        key: const ValueKey<String>('arrange'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            state.stage == SequencingStage.arrangeCombined
                ? 'Now combine both practiced halves into one full route.'
                : 'Arrange the steps in the order you heard.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SequencingReorderArea(
              cards: state.currentCards,
              onReorder: cubit.reorderCards,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.canReplay ? cubit.replayCurrentPart : null,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(state.canReplay ? 'Replay' : 'Replay Used'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Submit',
                  onPressed: cubit.submitCurrentOrder,
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (state.stage.isFeedback && state.lastResult != null) {
      return _FeedbackPanel(
        key: const ValueKey<String>('feedback'),
        result: state.lastResult!,
        onContinue: cubit.continueAfterFeedback,
      );
    }
    return const SizedBox.shrink();
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.result,
    required this.onContinue,
    super.key,
  });

  final SequencingRoundResult result;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final bool combined = result.stage == SequencingStage.arrangeCombined;
    final Color color = result.perfect ? AppColors.reward : AppColors.accent;
    final String title = result.perfect
        ? (combined ? 'Full route locked in' : 'Correct order')
        : '${result.correctPositions} of ${result.totalPositions} in place';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              result.perfect
                  ? Icons.check_circle_rounded
                  : Icons.psychology_alt_rounded,
              color: color,
              size: 46,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '+${result.pointsEarned}',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: color, fontSize: 42),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                itemCount: result.correctOrder.length + 2,
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Your order',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  if (index == result.correctOrder.length + 1) {
                    return _CorrectOrderList(result: result);
                  }
                  final int orderIndex = index - 1;
                  final bool correct = result.isCorrectAt(orderIndex);
                  final String text = orderIndex < result.userOrder.length
                      ? result.userOrder[orderIndex]
                      : 'Missing step';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: (correct ? AppColors.reward : AppColors.error)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (correct ? AppColors.reward : AppColors.error)
                              .withValues(alpha: 0.28),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              correct
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: correct
                                  ? AppColors.reward
                                  : AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${orderIndex + 1}. $text',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: combined ? 'Continue Route' : 'Continue',
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectOrderList extends StatelessWidget {
  const _CorrectOrderList({required this.result});

  final SequencingRoundResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Correct order', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          ...List<Widget>.generate(result.correctOrder.length, (int index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${index + 1}. ${result.correctOrder[index]}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.reward,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.cubit});

  final SequencingMemoryCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.86),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Paused',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
                PrimaryButton(label: 'Resume', onPressed: cubit.resume),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: cubit.restart,
                  child: const Text('Restart'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _stageTitle(SequencingStage stage) {
  return switch (stage) {
    SequencingStage.listenPartOne => 'Listen • Part One',
    SequencingStage.arrangePartOne => 'Arrange • Part One',
    SequencingStage.feedbackPartOne => 'Review • Part One',
    SequencingStage.listenPartTwo => 'Listen • Part Two',
    SequencingStage.arrangePartTwo => 'Arrange • Part Two',
    SequencingStage.feedbackPartTwo => 'Review • Part Two',
    SequencingStage.arrangeCombined => 'Combined Recall',
    SequencingStage.feedbackCombined => 'Combined Review',
    SequencingStage.paused => 'Paused',
    SequencingStage.initial || SequencingStage.finished => 'Sequencing Memory',
  };
}

String _listenLabel(SequencingStage stage) {
  return switch (stage) {
    SequencingStage.listenPartOne => 'Listening to part one',
    SequencingStage.listenPartTwo => 'Listening to part two',
    _ => 'Listening',
  };
}
