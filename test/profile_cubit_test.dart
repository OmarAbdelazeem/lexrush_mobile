import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/profile/application/cubit/profile_cubit.dart';
import 'package:lexrush/features/profile/application/cubit/profile_state.dart';
import 'package:lexrush/features/profile/domain/contracts/profile_repository.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';
import 'package:lexrush/shared/data/backend/user_achievements_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

void main() {
  group('ProfileCubit', () {
    test('loads progress with populated skills', () async {
      final ProfileCubit cubit = ProfileCubit(
        repository: _FakeProfileRepository(
          progress: _progress(),
          skills: const UserSkillsResponse(
            userId: 'dev-user-001',
            skills: <SkillProgressDto>[
              SkillProgressDto(
                skillId: 'punctuation',
                level: 5,
                masteryScore: 0.5,
                accuracy: 0.46,
                recentTrend: 'improving',
                confidence: 0.45,
              ),
            ],
          ),
          achievements: const UserAchievementsResponse(
            achievements: <UserAchievementDto>[
              UserAchievementDto(
                achievementId: 'first_step',
                title: 'First Step',
                description: 'Complete your first session',
                category: 'milestone',
                status: 'unlocked',
                progress: 1,
                target: 1,
                unlockedAt: '2026-06-01T12:00:00.000Z',
                iconKey: 'achievement_first_step',
              ),
            ],
          ),
        ),
      );

      await cubit.load();

      expect(cubit.state.status, ProfileStatus.loaded);
      expect(cubit.state.progress!.totalXp, 194);
      expect(cubit.state.skills.single.skillId, 'punctuation');
      expect(cubit.state.achievementsStatus, ProfileAchievementsStatus.loaded);
      expect(cubit.state.achievements.single.achievementId, 'first_step');

      await cubit.close();
    });

    test('uses emptySkills when skills list is empty', () async {
      final ProfileCubit cubit = ProfileCubit(
        repository: _FakeProfileRepository(
          progress: _progress(),
          skills: const UserSkillsResponse(
            userId: 'dev-user-001',
            skills: <SkillProgressDto>[],
          ),
        ),
      );

      await cubit.load();

      expect(cubit.state.status, ProfileStatus.emptySkills);
      expect(cubit.state.progress!.sessionsCompleted, 6);
      expect(cubit.state.skills, isEmpty);
      expect(cubit.state.achievementsStatus, ProfileAchievementsStatus.loaded);
      expect(cubit.state.achievements, isEmpty);

      await cubit.close();
    });

    test('achievement failure keeps loaded progress and skills', () async {
      final ProfileCubit cubit = ProfileCubit(
        repository: _FakeProfileRepository(
          progress: _progress(),
          skills: const UserSkillsResponse(
            userId: 'dev-user-001',
            skills: <SkillProgressDto>[
              SkillProgressDto(
                skillId: 'punctuation',
                level: 5,
                masteryScore: 0.5,
                accuracy: 0.46,
                recentTrend: 'improving',
                confidence: 0.45,
              ),
            ],
          ),
          achievementsError: Exception('achievements offline'),
        ),
      );

      await cubit.load();

      expect(cubit.state.status, ProfileStatus.loaded);
      expect(cubit.state.skills.single.skillId, 'punctuation');
      expect(cubit.state.achievements, isEmpty);
      expect(cubit.state.achievementsStatus, ProfileAchievementsStatus.error);
      expect(
        cubit.state.achievementsErrorMessage,
        'Achievements are unavailable right now.',
      );

      await cubit.close();
    });

    test('emits error when repository fails', () async {
      final ProfileCubit cubit = ProfileCubit(
        repository: _FakeProfileRepository(error: Exception('offline')),
      );

      await cubit.load();

      expect(cubit.state.status, ProfileStatus.error);
      expect(cubit.state.errorMessage, 'Progress is unavailable right now.');
      expect(cubit.state.achievementsStatus, ProfileAchievementsStatus.error);

      await cubit.close();
    });

    test('retry reloads data after an error', () async {
      final _QueuedProfileRepository repository = _QueuedProfileRepository();
      final ProfileCubit cubit = ProfileCubit(repository: repository);

      await cubit.load();
      expect(cubit.state.status, ProfileStatus.error);

      repository
        ..progress = _progress()
        ..skills = const UserSkillsResponse(
          userId: 'dev-user-001',
          skills: <SkillProgressDto>[],
        );
      await cubit.load();

      expect(cubit.state.status, ProfileStatus.emptySkills);
      expect(cubit.state.errorMessage, isNull);

      await cubit.close();
    });

    test(
      'load triggers pending result drain without blocking profile',
      () async {
        final _FakeResultRetryDrainer retryDrainer = _FakeResultRetryDrainer(
          drainCompleter: Completer<void>(),
        );
        final ProfileCubit cubit = ProfileCubit(
          repository: _FakeProfileRepository(
            progress: _progress(),
            skills: const UserSkillsResponse(
              userId: 'dev-user-001',
              skills: <SkillProgressDto>[],
            ),
          ),
          retryDrainer: retryDrainer,
          userId: 'user-1',
        );

        await cubit.load();

        expect(cubit.state.status, ProfileStatus.emptySkills);
        expect(retryDrainer.userIds, <String>['user-1']);

        retryDrainer.drainCompleter!.complete();
        await cubit.close();
      },
    );

    test('queue drain failure does not make profile load fail', () async {
      final _FakeResultRetryDrainer retryDrainer = _FakeResultRetryDrainer(
        drainError: Exception('queue unavailable'),
      );
      final ProfileCubit cubit = ProfileCubit(
        repository: _FakeProfileRepository(
          progress: _progress(),
          skills: const UserSkillsResponse(
            userId: 'dev-user-001',
            skills: <SkillProgressDto>[],
          ),
        ),
        retryDrainer: retryDrainer,
        userId: 'user-1',
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, ProfileStatus.emptySkills);
      expect(retryDrainer.userIds, <String>['user-1']);

      await cubit.close();
    });
  });
}

UserProgressResponse _progress() {
  return const UserProgressResponse(
    userId: 'dev-user-001',
    totalXp: 194,
    currentStreak: 1,
    longestStreak: 1,
    lastTrainingDay: '2026-05-27',
    sessionsCompleted: 6,
  );
}

class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository({
    this.progress,
    this.skills,
    this.achievements = const UserAchievementsResponse(
      achievements: <UserAchievementDto>[],
    ),
    this.error,
    this.achievementsError,
  });

  final UserProgressResponse? progress;
  final UserSkillsResponse? skills;
  final UserAchievementsResponse achievements;
  final Object? error;
  final Object? achievementsError;

  @override
  Future<UserProgressResponse> getProgress() async {
    if (error != null) throw error!;
    return progress!;
  }

  @override
  Future<UserSkillsResponse> getSkills() async {
    if (error != null) throw error!;
    return skills!;
  }

  @override
  Future<UserAchievementsResponse> getAchievements() async {
    final Object? error = achievementsError;
    if (error != null) throw error;
    return achievements;
  }
}

class _QueuedProfileRepository implements ProfileRepository {
  UserProgressResponse? progress;
  UserSkillsResponse? skills;
  UserAchievementsResponse achievements = const UserAchievementsResponse(
    achievements: <UserAchievementDto>[],
  );

  @override
  Future<UserProgressResponse> getProgress() async {
    final UserProgressResponse? value = progress;
    if (value == null) throw Exception('offline');
    return value;
  }

  @override
  Future<UserSkillsResponse> getSkills() async {
    final UserSkillsResponse? value = skills;
    if (value == null) throw Exception('offline');
    return value;
  }

  @override
  Future<UserAchievementsResponse> getAchievements() async {
    return achievements;
  }
}

class _FakeResultRetryDrainer implements ResultRetryDrainer {
  _FakeResultRetryDrainer({this.drainCompleter, this.drainError});

  final Completer<void>? drainCompleter;
  final Object? drainError;
  final List<String> userIds = <String>[];

  @override
  Future<void> drain({required String userId}) async {
    userIds.add(userId);
    final Object? error = drainError;
    if (error != null) throw error;
    final Completer<void>? completer = drainCompleter;
    if (completer != null) return completer.future;
  }
}
