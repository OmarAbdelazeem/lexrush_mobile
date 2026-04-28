import 'package:lexrush/shared/domain/contracts/progress_repository.dart';
import 'package:lexrush/shared/domain/entities/player_progress.dart';

class InMemoryProgressRepository implements ProgressRepository {
  PlayerProgress _progress = PlayerProgress.initial();

  @override
  Future<PlayerProgress> readProgress() async => _progress;

  @override
  Future<void> saveProgress(PlayerProgress progress) async {
    _progress = progress;
  }
}
