import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_theme.dart';
import 'package:lexrush/core/network/api_auth_headers_provider.dart';
import 'package:lexrush/core/network/api_client.dart';
import 'package:lexrush/core/network/api_config.dart';
import 'package:lexrush/features/onboarding/application/cubit/onboarding_flow_cubit.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';

class LexRushApp extends StatelessWidget {
  const LexRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<LexRushBackendRepository>(
          create: (_) => LexRushBackendRepository(
            apiClient: ApiClient(
              config: ApiConfig.fromEnvironment(),
              authHeadersProvider: ApiAuthHeadersProvider.dev(),
            ),
          ),
          dispose: (LexRushBackendRepository repository) => repository.close(),
        ),
      ],
      child: BlocProvider<OnboardingFlowCubit>(
        create: (_) => OnboardingFlowCubit()..loadStatus(),
        child: MaterialApp.router(
          title: 'LexRush',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}
