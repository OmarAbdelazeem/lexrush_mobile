import 'package:flutter/foundation.dart';
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
import 'package:lexrush/shared/application/services/debug_observability.dart';
import 'package:lexrush/shared/application/services/noop_integrations.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';
import 'package:lexrush/shared/application/services/pending_result_queue.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';
import 'package:lexrush/shared/domain/contracts/crash_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LexRushApp extends StatelessWidget {
  const LexRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<AnalyticsPort>(
          create: (_) =>
              kDebugMode ? DebugAnalyticsPort() : NoopAnalyticsPort(),
        ),
        RepositoryProvider<CrashReporter>(
          create: (_) =>
              kDebugMode ? DebugCrashReporter() : NoopCrashReporter(),
        ),
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
        RepositoryProvider<PendingResultQueue>(
          create: (_) => SharedPreferencesPendingResultQueue(
            preferences: SharedPreferencesAsync(),
          ),
        ),
        RepositoryProvider<ResultRetryDrainer>(
          create: (BuildContext context) => OfflineResultRetryCoordinator(
            queue: context.read<PendingResultQueue>(),
            repository: context.read<LexRushBackendRepository>(),
          ),
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
              retryDrainer: context.read<ResultRetryDrainer>(),
              analytics: context.read<AnalyticsPort>(),
              crashReporter: context.read<CrashReporter>(),
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
