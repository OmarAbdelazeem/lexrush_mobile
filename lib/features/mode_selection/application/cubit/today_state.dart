import 'package:equatable/equatable.dart';
import 'package:lexrush/shared/data/backend/today_dtos.dart';

enum TodayStatus { initial, loading, loaded, error }

class TodayState extends Equatable {
  const TodayState({
    required this.status,
    required this.today,
    required this.errorMessage,
  });

  const TodayState.initial()
    : this(status: TodayStatus.initial, today: null, errorMessage: null);

  final TodayStatus status;
  final TodayResponseDto? today;
  final String? errorMessage;

  TodayState copyWith({
    TodayStatus? status,
    TodayResponseDto? today,
    String? errorMessage,
    bool clearToday = false,
    bool clearError = false,
  }) {
    return TodayState(
      status: status ?? this.status,
      today: clearToday ? null : today ?? this.today,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, today, errorMessage];
}
