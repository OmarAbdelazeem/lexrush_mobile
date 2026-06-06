import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_theme.dart';
import 'package:lexrush/core/auth/auth_invalidation_controller.dart';
import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/auth/token_store.dart';
import 'package:lexrush/core/network/api_auth_headers_provider.dart';
import 'package:lexrush/core/network/api_client.dart';
import 'package:lexrush/core/network/api_config.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/auth/data/auth_repository.dart';
import 'package:lexrush/features/mode_selection/presentation/screens/mode_selection_screen.dart';
import 'package:lexrush/shared/application/services/noop_integrations.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/domain/contracts/analytics_port.dart';

void main() {
  testWidgets('logged-out Mode Selection does not fetch today', (
    WidgetTester tester,
  ) async {
    final List<String> paths = <String>[];

    await _pumpModeSelection(
      tester,
      tokenStore: _MemoryTokenStore(),
      onRequest: (http.Request request) async {
        paths.add(request.url.path);
        return http.Response('{}', 500);
      },
    );

    expect(find.text('Today’s Training'), findsOneWidget);
    expect(find.text('Sign in to see your daily plan.'), findsOneWidget);
    expect(find.text('Antonym Rush'), findsOneWidget);
    expect(paths, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated Mode Selection shows today card once', (
    WidgetTester tester,
  ) async {
    final List<String> paths = <String>[];

    await _pumpModeSelection(
      tester,
      tokenStore: _authenticatedTokenStore(),
      onRequest: (http.Request request) async {
        paths.add(request.url.path);
        return _modeSelectionResponse(request);
      },
    );
    await _waitForTodayRequest(tester, paths);

    expect(find.text('Keep Going!'), findsOneWidget);
    expect(find.text("1 of 2 games done — you're on a roll!"), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('53'), findsOneWidget);
    expect(paths.where((String path) => path == '/me/today'), hasLength(1));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(paths.where((String path) => path == '/me/today'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('today failure keeps game list usable', (
    WidgetTester tester,
  ) async {
    await _pumpModeSelection(
      tester,
      tokenStore: _authenticatedTokenStore(),
      onRequest: (http.Request request) async {
        if (request.url.path == '/me/today') {
          return http.Response('{}', 500);
        }
        return _modeSelectionResponse(request);
      },
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Today's training is unavailable right now."),
      findsOneWidget,
    );
    expect(find.text('Antonym Rush'), findsOneWidget);
    expect(find.text('Commas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed recommended game and skill labels render clearly', (
    WidgetTester tester,
  ) async {
    await _pumpModeSelection(
      tester,
      tokenStore: _authenticatedTokenStore(),
      onRequest: _modeSelectionResponse,
    );
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Processing Speed'), findsOneWidget);
    expect(find.text('Punctuation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping recommended commas routes to existing pre-game path', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpModeSelection(
      tester,
      tokenStore: _authenticatedTokenStore(),
      onRequest: _modeSelectionResponse,
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Commas').first);
    await tester.tap(find.text('Commas').first);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/pre-game/commas');
    expect(find.text('Pre-game commas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown recommended game is disabled and does not crash', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpModeSelection(
      tester,
      tokenStore: _authenticatedTokenStore(),
      onRequest: (http.Request request) async {
        if (request.url.path == '/me/today') {
          return _jsonResponse(<String, dynamic>{
            ..._todayJson(),
            'recommendedGames': <Map<String, dynamic>>[
              <String, dynamic>{
                'gameId': 'mystery_game',
                'title': 'Mystery Game',
                'skillFocus': <String>['mystery_skill'],
                'estimatedMinutes': 2,
                'completedToday': false,
              },
            ],
          }, 200);
        }
        return _modeSelectionResponse(request);
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Mystery Game'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);

    await tester.tap(find.text('Mystery Game'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/mode-selection');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _waitForTodayRequest(
  WidgetTester tester,
  List<String> paths,
) async {
  for (int i = 0; i < 10; i += 1) {
    if (paths.contains('/me/today')) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<GoRouter> _pumpModeSelection(
  WidgetTester tester, {
  required _MemoryTokenStore tokenStore,
  required Future<http.Response> Function(http.Request request) onRequest,
}) async {
  final AuthInvalidationController invalidationController =
      AuthInvalidationController();
  final ApiClient apiClient = ApiClient(
    config: const ApiConfig(baseUrl: 'http://example.test'),
    tokenStore: tokenStore,
    authHeadersProvider: ApiAuthHeadersProvider(tokenStore: tokenStore),
    httpClient: MockClient(onRequest),
  );
  final AuthRepository authRepository = AuthRepository(
    apiClient: apiClient,
    tokenStore: tokenStore,
  );
  final AuthCubit authCubit = AuthCubit(
    repository: authRepository,
    invalidationController: invalidationController,
  );
  addTearDown(authCubit.close);
  addTearDown(invalidationController.close);
  addTearDown(apiClient.close);

  await authCubit.initialize();

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.modeSelection,
    routes: <GoRoute>[
      GoRoute(
        path: AppRoutes.modeSelection,
        builder: (_, _) => const ModeSelectionScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.preGame}/:mode',
        builder: (_, GoRouterState state) {
          return Scaffold(
            body: Text('Pre-game ${state.pathParameters['mode']}'),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (_, _) => const Scaffold(body: Text('Auth')),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const Scaffold(body: Text('Profile')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<AnalyticsPort>(
          create: (_) => NoopAnalyticsPort(),
        ),
        RepositoryProvider<LexRushBackendRepository>(
          create: (_) => LexRushBackendRepository(apiClient: apiClient),
        ),
      ],
      child: BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

_MemoryTokenStore _authenticatedTokenStore() {
  return _MemoryTokenStore(
    const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
  );
}

Future<http.Response> _modeSelectionResponse(http.Request request) async {
  switch (request.url.path) {
    case '/auth/me':
      return http.Response(
        jsonEncode(<String, dynamic>{
          'userId': 'user-1',
          'email': 'user@example.com',
          'displayName': 'User',
        }),
        200,
        headers: _jsonHeaders,
      );
    case '/me/today':
      return _jsonResponse(_todayJson(), 200);
    default:
      return http.Response('{}', 404);
  }
}

const Map<String, String> _jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

http.Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return http.Response(jsonEncode(body), statusCode, headers: _jsonHeaders);
}

Map<String, dynamic> _todayJson() {
  return <String, dynamic>{
    'userId': 'user-1',
    'trainingDate': '2026-06-05',
    'status': 'in_progress',
    'title': 'Keep Going!',
    'message': "1 of 2 games done — you're on a roll!",
    'recommendedGames': <Map<String, dynamic>>[
      <String, dynamic>{
        'gameId': 'commas',
        'title': 'Commas',
        'skillFocus': <String>['grammar', 'punctuation', 'precision'],
        'estimatedMinutes': 2,
        'completedToday': true,
      },
      <String, dynamic>{
        'gameId': 'antonym_rush',
        'title': 'Antonym Rush',
        'skillFocus': <String>['vocabulary', 'processing_speed', 'attention'],
        'estimatedMinutes': 2,
        'completedToday': false,
      },
    ],
    'completedGameIds': <String>['commas'],
    'totalRecommendedGames': 2,
    'completedRecommendedGames': 1,
    'dailyXpEarned': 53,
    'currentStreak': 2,
  };
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore([this.tokens]);

  AuthTokens? tokens;

  @override
  Future<void> clearTokens() async {
    tokens = null;
  }

  @override
  Future<AuthTokens?> readTokens() async {
    return tokens;
  }

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    this.tokens = tokens;
  }
}
