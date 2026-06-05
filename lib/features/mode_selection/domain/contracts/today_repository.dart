import 'package:lexrush/shared/data/backend/today_dtos.dart';

abstract interface class TodayRepository {
  Future<TodayResponseDto> getToday();
}
