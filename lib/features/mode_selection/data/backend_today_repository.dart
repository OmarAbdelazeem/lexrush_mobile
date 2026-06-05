import 'package:lexrush/features/mode_selection/domain/contracts/today_repository.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/today_dtos.dart';

class BackendTodayRepository implements TodayRepository {
  const BackendTodayRepository(this._backendRepository);

  final LexRushBackendRepository _backendRepository;

  @override
  Future<TodayResponseDto> getToday() {
    return _backendRepository.getToday();
  }
}
