import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_theme.dart';
import 'package:lexrush/features/onboarding/application/cubit/onboarding_flow_cubit.dart';

class LexRushApp extends StatelessWidget {
  const LexRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OnboardingFlowCubit>(
      create: (_) => OnboardingFlowCubit()..loadStatus(),
      child: MaterialApp.router(
        title: 'LexRush',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
