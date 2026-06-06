import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexrush/features/profile/application/cubit/profile_state.dart';
import 'package:lexrush/features/profile/domain/contracts/profile_repository.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';
import 'package:lexrush/shared/data/backend/user_achievements_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required ProfileRepository repository,
    ResultRetryDrainer? retryDrainer,
    String? userId,
    AnalyticsPort? analytics,
  }) : _repository = repository,
       _retryDrainer = retryDrainer,
       _userId = userId,
       _analytics = analytics,
       super(ProfileState.initial());

  final AnalyticsPort? _analytics;

  final ProfileRepository _repository;
  final ResultRetryDrainer? _retryDrainer;
  final String? _userId;

  Future<void> load() async {
    _drainPendingResults();
    emit(
      state.copyWith(
        status: ProfileStatus.loading,
        skills: <SkillProgressDto>[],
        achievementsStatus: ProfileAchievementsStatus.loading,
        achievements: <UserAchievementDto>[],
        clearError: true,
        clearAchievementsError: true,
      ),
    );

    final Future<_AchievementsLoadResult> achievementsFuture = _repository
        .getAchievements()
        .then<_AchievementsLoadResult>(_AchievementsLoadResult.success)
        .catchError((Object _) => const _AchievementsLoadResult.error());

    try {
      final (UserProgressResponse progress, UserSkillsResponse skills) = await (
        _repository.getProgress(),
        _repository.getSkills(),
      ).wait;

      emit(
        state.copyWith(
          status: skills.skills.isEmpty
              ? ProfileStatus.emptySkills
              : ProfileStatus.loaded,
          progress: progress,
          skills: skills.skills,
          achievementsStatus: ProfileAchievementsStatus.loading,
          clearError: true,
          clearAchievementsError: true,
        ),
      );

      final _AchievementsLoadResult achievementsResult =
          await achievementsFuture;
      final UserAchievementsResponse? achievements =
          achievementsResult.response;
      if (achievements == null) {
        emit(
          state.copyWith(
            achievementsStatus: ProfileAchievementsStatus.error,
            achievements: <UserAchievementDto>[],
            achievementsErrorMessage: 'Achievements are unavailable right now.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          achievementsStatus: ProfileAchievementsStatus.loaded,
          achievements: achievements.achievements,
          clearAchievementsError: true,
        ),
      );
      unawaited(
        _analytics
            ?.trackProfileLoaded(
              achievementsCount: achievements.achievements.length,
              unlockedAchievementsCount: achievements.achievements
                  .where((a) => a.unlockedAt != null)
                  .length,
            )
            .catchError((_) {}),
      );
    } on Object {
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          achievementsStatus: ProfileAchievementsStatus.error,
          errorMessage: 'Progress is unavailable right now.',
        ),
      );
    }
  }

  void _drainPendingResults() {
    final ResultRetryDrainer? retryDrainer = _retryDrainer;
    final String? userId = _userId;
    if (retryDrainer == null || userId == null || userId.isEmpty) return;
    unawaited(retryDrainer.drain(userId: userId).catchError((_) {}));
  }
}

class _AchievementsLoadResult {
  const _AchievementsLoadResult.success(this.response);

  const _AchievementsLoadResult.error() : response = null;

  final UserAchievementsResponse? response;
}
