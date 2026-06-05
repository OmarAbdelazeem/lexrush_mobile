import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/auth/application/auth_state.dart';
import 'package:lexrush/features/mode_selection/application/cubit/today_cubit.dart';
import 'package:lexrush/features/mode_selection/application/cubit/today_state.dart';
import 'package:lexrush/features/mode_selection/data/backend_today_repository.dart';
import 'package:lexrush/shared/application/services/game_registry_service.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/today_dtos.dart';
import 'package:lexrush/shared/domain/entities/game_definition.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';
import 'package:lexrush/shared/domain/entities/game_mode_codec.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TodayCubit>(
      create: (BuildContext context) => TodayCubit(
        repository: BackendTodayRepository(
          context.read<LexRushBackendRepository>(),
        ),
      ),
      child: const _ModeSelectionView(),
    );
  }
}

class _ModeSelectionView extends StatefulWidget {
  const _ModeSelectionView();

  @override
  State<_ModeSelectionView> createState() => _ModeSelectionViewState();
}

class _ModeSelectionViewState extends State<_ModeSelectionView> {
  bool _checkedInitialAuthState = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedInitialAuthState) return;

    _checkedInitialAuthState = true;
    if (context.read<AuthCubit>().state.isAuthenticated) {
      context.read<TodayCubit>().loadIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameRegistryService registry = GameRegistryService.defaultRegistry();
    final List<GameDefinition> games = registry.listAll();
    debugPrint('[ModeSelectionScreen] rendering modes count=${games.length}');

    return PortraitShell(
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (AuthState previous, AuthState current) =>
            previous.status != current.status,
        listener: (BuildContext context, AuthState authState) {
          final TodayCubit todayCubit = context.read<TodayCubit>();
          if (authState.isAuthenticated) {
            todayCubit.loadIfNeeded();
          } else if (authState.status == AuthStatus.unauthenticated ||
              authState.status == AuthStatus.error) {
            todayCubit.reset();
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (BuildContext context, AuthState authState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Choose Mode',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push(AppRoutes.profile),
                        icon: const Icon(Icons.insights_rounded, size: 20),
                        tooltip: 'Progress',
                      ),
                      if (authState.isAuthenticated)
                        IconButton(
                          onPressed: () => context.read<AuthCubit>().logout(),
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          tooltip: 'Sign out',
                        )
                      else
                        IconButton(
                          onPressed: () => context.push(AppRoutes.auth),
                          icon: const Icon(Icons.person_rounded, size: 20),
                          tooltip: 'Sign in',
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select your challenge',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sharpen speed. Master words.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.accent),
                  ),
                  const SizedBox(height: 16),
                  _TodaySection(authState: authState),
                  const SizedBox(height: 20),
                  ...games.asMap().entries.map((
                    MapEntry<int, GameDefinition> entry,
                  ) {
                    final int index = entry.key;
                    final GameDefinition game = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == games.length - 1 ? 0 : 12,
                      ),
                      child: _ModeCard(
                        title: game.title,
                        subtitle: game.description,
                        icon: _iconForMode(game.mode),
                        color: _colorForMode(game.mode),
                        isAvailable: !game.isLocked,
                        onTap: !game.isLocked
                            ? () {
                                debugPrint(
                                  '[ModeSelectionScreen] selected mode=${game.id}',
                                );
                                context.go(
                                  '${AppRoutes.preGame}/${GameModeCodec.toPath(game.mode)}',
                                );
                              }
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconForMode(GameMode mode) {
    switch (mode) {
      case GameMode.antonymRush:
        return Icons.local_fire_department_rounded;
      case GameMode.synonymStorm:
        return Icons.auto_awesome_rounded;
      case GameMode.definitionMatch:
        return Icons.menu_book_rounded;
      case GameMode.association:
        return Icons.hub_rounded;
      case GameMode.sequencingMemory:
        return Icons.route_rounded;
      case GameMode.commas:
        return Icons.format_quote_rounded;
    }
  }

  Color _colorForMode(GameMode mode) {
    switch (mode) {
      case GameMode.antonymRush:
        return AppColors.primary;
      case GameMode.synonymStorm:
        return AppColors.accent;
      case GameMode.definitionMatch:
        return AppColors.reward;
      case GameMode.association:
        return AppColors.primary;
      case GameMode.sequencingMemory:
        return AppColors.accent;
      case GameMode.commas:
        return AppColors.reward;
    }
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    if (!authState.isAuthenticated) {
      return const _TodayInfoCard(
        icon: Icons.lock_rounded,
        title: 'Today’s Training',
        message: 'Sign in to see your daily plan.',
        color: AppColors.accent,
      );
    }

    return BlocBuilder<TodayCubit, TodayState>(
      builder: (BuildContext context, TodayState state) {
        switch (state.status) {
          case TodayStatus.initial:
          case TodayStatus.loading:
            return const _TodayLoadingCard();
          case TodayStatus.error:
            return _TodayInfoCard(
              icon: Icons.cloud_off_rounded,
              title: 'Today’s Training',
              message:
                  state.errorMessage ??
                  'Today’s training is unavailable right now.',
              color: AppColors.error,
            );
          case TodayStatus.loaded:
            final TodayResponseDto? today = state.today;
            if (today == null) {
              return const _TodayInfoCard(
                icon: Icons.cloud_off_rounded,
                title: 'Today’s Training',
                message: 'Today’s training is unavailable right now.',
                color: AppColors.error,
              );
            }
            return _TodayCard(today: today);
        }
      },
    );
  }
}

class _TodayLoadingCard extends StatelessWidget {
  const _TodayLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading today’s training...',
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayInfoCard extends StatelessWidget {
  const _TodayInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});

  final TodayResponseDto today;

  @override
  Widget build(BuildContext context) {
    final Color accent = today.isCompleted
        ? AppColors.reward
        : AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                today.isCompleted
                    ? Icons.celebration_rounded
                    : Icons.today_rounded,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  today.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(today.message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _TodayMetric(
                label: 'Plan',
                value:
                    '${today.completedRecommendedGames}/${today.totalRecommendedGames}',
              ),
              const SizedBox(width: 8),
              _TodayMetric(label: 'Streak', value: '${today.currentStreak}'),
              const SizedBox(width: 8),
              _TodayMetric(label: 'Today XP', value: '${today.dailyXpEarned}'),
            ],
          ),
          if (today.recommendedGames.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            ...today.recommendedGames.map(
              (RecommendedGameDto game) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecommendedGameRow(game: game),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedGameRow extends StatelessWidget {
  const _RecommendedGameRow({required this.game});

  final RecommendedGameDto game;

  @override
  Widget build(BuildContext context) {
    final GameMode? mode = _modeForBackendGameId(game.gameId);
    final bool isAvailable = mode != null;
    final Color color = game.completedToday
        ? AppColors.reward
        : isAvailable
        ? AppColors.accent
        : AppColors.textSecondary;

    return Opacity(
      opacity: isAvailable ? 1 : 0.58,
      child: Material(
        color: AppColors.background.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isAvailable
              ? () {
                  context.go(
                    '${AppRoutes.preGame}/${GameModeCodec.toPath(mode)}',
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      game.completedToday
                          ? Icons.check_circle_rounded
                          : isAvailable
                          ? Icons.play_circle_fill_rounded
                          : Icons.block_rounded,
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        game.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      game.completedToday
                          ? 'Done'
                          : isAvailable
                          ? '${game.estimatedMinutes} min'
                          : 'Unavailable',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (game.skillFocus.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: game.skillFocus
                        .map(
                          (String skill) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _labelFromSnakeCase(skill),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isAvailable,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isAvailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isAvailable ? 1 : 0.55,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        color,
                        Color.lerp(color, Colors.white, 0.18)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isAvailable ? icon : Icons.lock_rounded,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (!isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Soon',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

GameMode? _modeForBackendGameId(String gameId) {
  switch (gameId) {
    case 'commas':
      return GameMode.commas;
    case 'antonym_rush':
      return GameMode.antonymRush;
    case 'association':
      return GameMode.association;
    case 'sequencing_memory':
      return GameMode.sequencingMemory;
    default:
      return null;
  }
}

String _labelFromSnakeCase(String value) {
  return value
      .split('_')
      .where((String word) => word.isNotEmpty)
      .map((String word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
