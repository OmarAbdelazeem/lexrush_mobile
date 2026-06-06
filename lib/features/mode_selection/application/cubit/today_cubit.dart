import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexrush/features/mode_selection/application/cubit/today_state.dart';
import 'package:lexrush/features/mode_selection/domain/contracts/today_repository.dart';
import 'package:lexrush/shared/data/backend/today_dtos.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';

class TodayCubit extends Cubit<TodayState> {
  TodayCubit({required TodayRepository repository, AnalyticsPort? analytics})
    : _repository = repository,
      _analytics = analytics,
      super(const TodayState.initial());

  final TodayRepository _repository;
  final AnalyticsPort? _analytics;

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
      unawaited(
        _analytics
            ?.trackTodayLoaded(
              status: today.status,
              completedRecommendedGames: today.completedGameIds.length,
              totalRecommendedGames: today.totalRecommendedGames,
            )
            .catchError((_) {}),
      );
    } on Object {
      emit(
        state.copyWith(
          status: TodayStatus.error,
          errorMessage: "Today's training is unavailable right now.",
        ),
      );
    }
  }

  void reset() {
    if (state.status == TodayStatus.initial) return;
    emit(const TodayState.initial());
  }
}
