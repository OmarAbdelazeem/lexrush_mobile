import 'package:equatable/equatable.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

enum ProfileStatus { initial, loading, loaded, emptySkills, error }

class ProfileState extends Equatable {
  const ProfileState({
    required this.status,
    required this.progress,
    required this.skills,
    required this.errorMessage,
  });

  factory ProfileState.initial() {
    return const ProfileState(
      status: ProfileStatus.initial,
      progress: null,
      skills: <SkillProgressDto>[],
      errorMessage: null,
    );
  }

  final ProfileStatus status;
  final UserProgressResponse? progress;
  final List<SkillProgressDto> skills;
  final String? errorMessage;

  ProfileState copyWith({
    ProfileStatus? status,
    UserProgressResponse? progress,
    List<SkillProgressDto>? skills,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      skills: skills ?? this.skills,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, progress, skills, errorMessage];
}
