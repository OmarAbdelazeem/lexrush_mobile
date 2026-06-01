import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexrush/core/auth/auth_invalidation_controller.dart';
import 'package:lexrush/core/auth/token_store.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_theme.dart';
import 'package:lexrush/core/network/api_auth_headers_provider.dart';
import 'package:lexrush/core/network/api_client.dart';
import 'package:lexrush/core/network/api_config.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/auth/data/auth_repository.dart';
import 'package:lexrush/features/onboarding/application/cubit/onboarding_flow_cubit.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';

class LexRushApp extends StatelessWidget {
  const LexRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<TokenStore>(create: (_) => const SecureTokenStore()),
        RepositoryProvider<AuthInvalidationController>(
          create: (_) => AuthInvalidationController(),
          dispose: (AuthInvalidationController controller) =>
              controller.close(),
        ),
        RepositoryProvider<ApiClient>(
          create: (BuildContext context) {
            final TokenStore tokenStore = context.read<TokenStore>();
            final AuthInvalidationController invalidationController = context
                .read<AuthInvalidationController>();
            return ApiClient(
              config: ApiConfig.fromEnvironment(),
              tokenStore: tokenStore,
              authHeadersProvider: ApiAuthHeadersProvider(
                tokenStore: tokenStore,
              ),
              onAuthInvalidated: invalidationController.notifyInvalidated,
            );
          },
          dispose: (ApiClient client) => client.close(),
        ),
        RepositoryProvider<AuthRepository>(
          create: (BuildContext context) => AuthRepository(
            apiClient: context.read<ApiClient>(),
            tokenStore: context.read<TokenStore>(),
          ),
        ),
        RepositoryProvider<LexRushBackendRepository>(
          create: (BuildContext context) =>
              LexRushBackendRepository(apiClient: context.read<ApiClient>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<OnboardingFlowCubit>(
            create: (_) => OnboardingFlowCubit()..loadStatus(),
          ),
          BlocProvider<AuthCubit>(
            create: (BuildContext context) => AuthCubit(
              repository: context.read<AuthRepository>(),
              invalidationController: context
                  .read<AuthInvalidationController>(),
            )..initialize(),
          ),
        ],
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
