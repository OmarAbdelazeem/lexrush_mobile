import 'package:lexrush/shared/data/backend/user_progress_dtos.dart';
import 'package:lexrush/shared/data/backend/user_skills_dtos.dart';

abstract interface class ProfileRepository {
  Future<UserProgressResponse> getProgress();

  Future<UserSkillsResponse> getSkills();
}
