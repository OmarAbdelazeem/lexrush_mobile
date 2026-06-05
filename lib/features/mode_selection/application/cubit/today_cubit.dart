import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexrush/features/mode_selection/application/cubit/today_state.dart';
import 'package:lexrush/features/mode_selection/domain/contracts/today_repository.dart';
import 'package:lexrush/shared/data/backend/today_dtos.dart';

class TodayCubit extends Cubit<TodayState> {
  TodayCubit({required TodayRepository repository})
    : _repository = repository,
      super(const TodayState.initial());

  final TodayRepository _repository;

  Future<void> loadIfNeeded() async {
    if (state.status != TodayStatus.initial) return;
    emit(state.copyWith(status: TodayStatus.loading, clearError: true));

    try {
      final TodayResponseDto today = await _repository.getToday();
      emit(
        state.copyWith(
          status: TodayStatus.loaded,
          today: today,
          clearError: true,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          status: TodayStatus.error,
          errorMessage: 'Today’s training is unavailable right now.',
        ),
      );
    }
  }

  void reset() {
    if (state.status == TodayStatus.initial) return;
    emit(const TodayState.initial());
  }
}
