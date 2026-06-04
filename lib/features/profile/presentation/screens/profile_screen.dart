import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/auth/application/auth_state.dart';
import 'package:lexrush/features/profile/application/cubit/profile_cubit.dart';
import 'package:lexrush/features/profile/application/cubit/profile_state.dart';
import 'package:lexrush/features/profile/data/backend_profile_repository.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';
import 'package:lexrush/shared/presentation/widgets/primary_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (BuildContext context) => ProfileCubit(
        repository: BackendProfileRepository(
          context.read<LexRushBackendRepository>(),
        ),
        retryDrainer: context.read<ResultRetryDrainer>(),
        userId: context.read<AuthCubit>().state.user?.userId,
      ),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return PortraitShell(
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (BuildContext context, AuthState authState) {
          final bool isWaitingForAuth =
              authState.status == AuthStatus.initial ||
              authState.status == AuthStatus.loading;
          final bool canLoadProgress = authState.isAuthenticated;

          return BlocBuilder<ProfileCubit, ProfileState>(
            builder: (BuildContext context, ProfileState state) {
              if (canLoadProgress && state.status == ProfileStatus.initial) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.read<ProfileCubit>().load();
                  }
                });
              }

              return CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                      child: _Header(onBack: context.pop),
                    ),
                  ),
                  if (isWaitingForAuth)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!canLoadProgress)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SignInPrompt(
                        onSignIn: () => context.push(AppRoutes.auth),
                      ),
                    )
                  else if (state.status == ProfileStatus.loading ||
                      state.status == ProfileStatus.initial)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.status == ProfileStatus.error)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(
                        message:
                            state.errorMessage ??
                            'Progress is unavailable right now.',
                        onRetry: context.read<ProfileCubit>().load,
                      ),
                    )
                  else
                    _LoadedProfile(state: state),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.lock_rounded, color: AppColors.accent, size: 44),
          const SizedBox(height: 14),
          Text(
            'Sign in to view progress',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your local games still work. Sign in when you want XP, streaks, and skill insights saved.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Sign In', onPressed: onSignIn),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Back',
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Progress',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Your LexRush profile',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadedProfile extends StatelessWidget {
  const _LoadedProfile({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final UserProgressResponse progress = state.progress!;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      sliver: SliverList.list(
        children: <Widget>[
          _XpSummaryCard(progress: progress),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatCard(
                  label: 'Current',
                  value: '${progress.currentStreak}',
                  suffix: 'streak',
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Longest',
                  value: '${progress.longestStreak}',
                  suffix: 'streak',
                  icon: Icons.emoji_events_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatCard(
            label: 'Sessions Completed',
            value: '${progress.sessionsCompleted}',
            suffix: 'sessions',
            icon: Icons.check_circle_rounded,
            wide: true,
          ),
          const SizedBox(height: 22),
          Text('Skill Mastery', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (state.status == ProfileStatus.emptySkills)
            const _EmptySkillsCard()
          else
            ...state.skills.map(
              (SkillProgressDto skill) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SkillCard(skill: skill),
              ),
            ),
        ],
      ),
    );
  }
}

class _XpSummaryCard extends StatelessWidget {
  const _XpSummaryCard({required this.progress});

  final UserProgressResponse progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
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
              Icon(Icons.workspace_premium_rounded, color: AppColors.reward),
              const SizedBox(width: 8),
              Text('Total XP', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${progress.totalXp}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (progress.lastTrainingDay != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Last trained ${progress.lastTrainingDay}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    this.wide = false,
  });

  final String label;
  final String value;
  final String suffix;
  final IconData icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: wide ? 76 : 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  '$value $suffix',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});

  final SkillProgressDto skill;

  @override
  Widget build(BuildContext context) {
    final _TrendStyle trend = _trendStyle(skill.recentTrend);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: trend.color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _titleCaseSkill(skill.skillId),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: trend.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(trend.icon, size: 16, color: trend.color),
                    const SizedBox(width: 5),
                    Text(
                      skill.recentTrend,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: trend.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _Metric(label: 'Level', value: '${skill.level}'),
              _Metric(label: 'Mastery', value: _percent(skill.masteryScore)),
              _Metric(label: 'Accuracy', value: _percent(skill.accuracy)),
              _Metric(label: 'Confidence', value: _percent(skill.confidence)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptySkillsCard extends StatelessWidget {
  const _EmptySkillsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Complete your first session to unlock skill insights.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 54),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _TrendStyle {
  const _TrendStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_TrendStyle _trendStyle(String trend) {
  switch (trend) {
    case 'improving':
      return const _TrendStyle(
        icon: Icons.trending_up_rounded,
        color: AppColors.reward,
      );
    case 'declining':
      return const _TrendStyle(
        icon: Icons.trending_down_rounded,
        color: AppColors.error,
      );
    case 'stable':
    default:
      return const _TrendStyle(
        icon: Icons.trending_flat_rounded,
        color: AppColors.textSecondary,
      );
  }
}

String _percent(double value) => '${(value * 100).round()}%';

String _titleCaseSkill(String skillId) {
  return skillId
      .split('_')
      .where((String word) => word.isNotEmpty)
      .map((String word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
