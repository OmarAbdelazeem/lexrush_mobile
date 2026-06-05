import 'package:equatable/equatable.dart';
import 'package:lexrush/shared/data/backend/user_achievements_dtos.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

enum ProfileStatus { initial, loading, loaded, emptySkills, error }

enum ProfileAchievementsStatus { initial, loading, loaded, error }

class ProfileState extends Equatable {
  const ProfileState({
    required this.status,
    required this.progress,
    required this.skills,
    required this.achievementsStatus,
    required this.achievements,
    required this.errorMessage,
    required this.achievementsErrorMessage,
  });

  factory ProfileState.initial() {
    return const ProfileState(
      status: ProfileStatus.initial,
      progress: null,
      skills: <SkillProgressDto>[],
      achievementsStatus: ProfileAchievementsStatus.initial,
      achievements: <UserAchievementDto>[],
      errorMessage: null,
      achievementsErrorMessage: null,
    );
  }

  final ProfileStatus status;
  final UserProgressResponse? progress;
  final List<SkillProgressDto> skills;
  final ProfileAchievementsStatus achievementsStatus;
  final List<UserAchievementDto> achievements;
  final String? errorMessage;
  final String? achievementsErrorMessage;

  ProfileState copyWith({
    ProfileStatus? status,
    UserProgressResponse? progress,
    List<SkillProgressDto>? skills,
    ProfileAchievementsStatus? achievementsStatus,
    List<UserAchievementDto>? achievements,
    String? errorMessage,
    String? achievementsErrorMessage,
    bool clearError = false,
    bool clearAchievementsError = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      skills: skills ?? this.skills,
      achievementsStatus: achievementsStatus ?? this.achievementsStatus,
      achievements: achievements ?? this.achievements,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      achievementsErrorMessage: clearAchievementsError
          ? null
          : achievementsErrorMessage ?? this.achievementsErrorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    progress,
    skills,
    achievementsStatus,
    achievements,
    errorMessage,
    achievementsErrorMessage,
  ];
}
