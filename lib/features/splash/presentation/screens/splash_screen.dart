import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/onboarding/application/cubit/onboarding_flow_cubit.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _minimumSplashDuration = Duration(milliseconds: 2500);
  Timer? _timer;
  bool _minimumDurationReached = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minimumSplashDuration, () {
      _minimumDurationReached = true;
      _tryNavigate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tryNavigate() {
    if (_navigated || !_minimumDurationReached || !mounted) return;

    final OnboardingFlowState state = context.read<OnboardingFlowCubit>().state;
    if (state.isLoading) return;

    debugPrint(
      '[SplashScreen] navigating hasSeenOnboarding=${state.hasSeenOnboarding}',
    );
    _navigated = true;
    context.go(
      state.hasSeenOnboarding ? AppRoutes.modeSelection : AppRoutes.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingFlowCubit, OnboardingFlowState>(
      listener: (_, onboardingState) => _tryNavigate(),
      child: PortraitShell(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 72),
              const SizedBox(height: 16),
              Text('LexRush', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Sharpen Speed. Master Words.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
