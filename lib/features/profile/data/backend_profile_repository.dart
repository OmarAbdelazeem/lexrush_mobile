import 'package:lexrush/features/profile/domain/contracts/profile_repository.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

class BackendProfileRepository implements ProfileRepository {
  const BackendProfileRepository(this._backendRepository);

  final LexRushBackendRepository _backendRepository;

  @override
  Future<UserProgressResponse> getProgress() {
    return _backendRepository.getMyProgress();
  }

  @override
  Future<UserSkillsResponse> getSkills() {
    return _backendRepository.getMySkills();
  }
}
