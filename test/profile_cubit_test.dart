import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/profile/application/cubit/profile_cubit.dart';
import 'package:lexrush/features/profile/application/cubit/profile_state.dart';
import 'package:lexrush/features/profile/domain/contracts/profile_repository.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';
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
        ),
      );

      await cubit.load();

      expect(cubit.state.status, ProfileStatus.loaded);
      expect(cubit.state.progress!.totalXp, 194);
      expect(cubit.state.skills.single.skillId, 'punctuation');

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

      await cubit.close();
    });

    test('emits error when repository fails', () async {
      final ProfileCubit cubit = ProfileCubit(
        repository: _FakeProfileRepository(error: Exception('offline')),
      );

      await cubit.load();

      expect(cubit.state.status, ProfileStatus.error);
      expect(cubit.state.errorMessage, 'Progress is unavailable right now.');

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
  const _FakeProfileRepository({this.progress, this.skills, this.error});

  final UserProgressResponse? progress;
  final UserSkillsResponse? skills;
  final Object? error;

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
}

class _QueuedProfileRepository implements ProfileRepository {
  UserProgressResponse? progress;
  UserSkillsResponse? skills;

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
