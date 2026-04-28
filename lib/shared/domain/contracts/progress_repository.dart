import 'package:lexrush/shared/domain/entities/player_progress.dart';

abstract class ProgressRepository {
  Future<PlayerProgress> readProgress();
  Future<void> saveProgress(PlayerProgress progress);
}
