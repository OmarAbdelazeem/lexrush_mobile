import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingFlowState extends Equatable {
  const OnboardingFlowState({
    required this.isLoading,
    required this.hasSeenOnboarding,
  });

  const OnboardingFlowState.initial()
      : isLoading = true,
        hasSeenOnboarding = false;

  final bool isLoading;
  final bool hasSeenOnboarding;

  OnboardingFlowState copyWith({
    bool? isLoading,
    bool? hasSeenOnboarding,
  }) {
    return OnboardingFlowState(
      isLoading: isLoading ?? this.isLoading,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    );
  }

  @override
  List<Object> get props => <Object>[isLoading, hasSeenOnboarding];
}

class OnboardingFlowCubit extends Cubit<OnboardingFlowState> {
  OnboardingFlowCubit() : super(const OnboardingFlowState.initial());

  static const String _onboardingSeenKey = 'lexrush_has_seen_onboarding';

  Future<void> loadStatus() async {
    debugPrint('[OnboardingFlowCubit] loadStatus');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool(_onboardingSeenKey) ?? false;
    debugPrint('[OnboardingFlowCubit] loaded hasSeenOnboarding=$hasSeenOnboarding');
    emit(
      state.copyWith(
        isLoading: false,
        hasSeenOnboarding: hasSeenOnboarding,
      ),
    );
  }

  Future<void> completeOnboarding() async {
    debugPrint('[OnboardingFlowCubit] completeOnboarding');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
    debugPrint('[OnboardingFlowCubit] persisted $_onboardingSeenKey=true');
    emit(
      state.copyWith(
        isLoading: false,
        hasSeenOnboarding: true,
      ),
    );
  }
}
