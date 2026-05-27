import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexrush/features/profile/application/cubit/profile_state.dart';
import 'package:lexrush/features/profile/domain/contracts/profile_repository.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required ProfileRepository repository})
    : _repository = repository,
      super(ProfileState.initial());

  final ProfileRepository _repository;

  Future<void> load() async {
    emit(
      state.copyWith(
        status: ProfileStatus.loading,
        skills: <SkillProgressDto>[],
        clearError: true,
      ),
    );

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
          clearError: true,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'Progress is unavailable right now.',
        ),
      );
    }
  }
}
