import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexrush/app/theme/app_theme.dart';
import 'package:lexrush/core/auth/auth_invalidation_controller.dart';
import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/auth/token_store.dart';
import 'package:lexrush/core/network/api_auth_headers_provider.dart';
import 'package:lexrush/core/network/api_client.dart';
import 'package:lexrush/core/network/api_config.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/auth/data/auth_repository.dart';
import 'package:lexrush/features/profile/presentation/screens/profile_screen.dart';
import 'package:lexrush/features/profile/presentation/widgets/achievement_card.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';
import 'package:lexrush/shared/data/backend/lexrush_backend_repository.dart';
import 'package:lexrush/shared/data/backend/user_achievements_dtos.dart';

void main() {
  testWidgets('AchievementCard renders unlocked state and date', (
    WidgetTester tester,
  ) async {
    await _pumpCard(
      tester,
      const UserAchievementDto(
        achievementId: 'first_step',
        title: 'First Step',
        description: 'Complete your first session',
        category: 'milestone',
        status: 'unlocked',
        progress: 1,
        target: 1,
        unlockedAt: '2026-06-01T12:00:00.000Z',
        iconKey: 'achievement_first_step',
      ),
    );

    expect(find.text('First Step'), findsOneWidget);
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Unlocked Jun 1, 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AchievementCard renders locked progress defensively', (
    WidgetTester tester,
  ) async {
    await _pumpCard(
      tester,
      const UserAchievementDto(
        achievementId: 'getting_warmed_up',
        title: 'Getting Warmed Up',
        description: 'Complete five sessions',
        category: 'milestone',
        status: 'locked',
        progress: 2,
        target: 5,
        unlockedAt: null,
        iconKey: 'achievement_getting_warmed_up',
      ),
    );

    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AchievementCard handles target zero safely', (
    WidgetTester tester,
  ) async {
    await _pumpCard(
      tester,
      const UserAchievementDto(
        achievementId: 'unknown',
        title: 'Unknown',
        description: 'Unknown target',
        category: 'milestone',
        status: 'locked',
        progress: -1,
        target: 0,
        unlockedAt: null,
        iconKey: 'unknown_icon',
      ),
    );

    expect(find.text('0 / 0'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logged-out Profile does not fetch or drain', (
    WidgetTester tester,
  ) async {
    final List<String> paths = <String>[];
    final _FakeResultRetryDrainer retryDrainer = _FakeResultRetryDrainer();

    await _pumpProfile(
      tester,
      tokenStore: _MemoryTokenStore(),
      retryDrainer: retryDrainer,
      onRequest: (http.Request request) async {
        paths.add(request.url.path);
        return http.Response('{}', 500);
      },
    );

    expect(find.text('Sign in to view progress'), findsOneWidget);
    expect(paths, isEmpty);
    expect(retryDrainer.userIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile shows empty achievements state', (
    WidgetTester tester,
  ) async {
    final _FakeResultRetryDrainer retryDrainer = _FakeResultRetryDrainer();

    await _pumpProfile(
      tester,
      tokenStore: _MemoryTokenStore(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      ),
      retryDrainer: retryDrainer,
      onRequest: _profileResponse,
    );

    expect(find.text('Total XP'), findsOneWidget);
    await _scrollProfileDown(tester);
    expect(find.text('Achievements'), findsOneWidget);
    expect(
      find.text('Complete sessions to unlock achievements.'),
      findsOneWidget,
    );
    expect(retryDrainer.userIds, <String>['user-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile shows inline achievements error only', (
    WidgetTester tester,
  ) async {
    await _pumpProfile(
      tester,
      tokenStore: _MemoryTokenStore(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      ),
      retryDrainer: _FakeResultRetryDrainer(),
      onRequest: (http.Request request) async {
        if (request.url.path == '/me/achievements') {
          return http.Response('{}', 500);
        }
        return _profileResponse(request);
      },
    );

    expect(find.text('Total XP'), findsOneWidget);
    await _scrollProfileDown(tester);
    expect(find.text('Skill Mastery'), findsOneWidget);
    expect(
      find.text('Achievements are unavailable right now.'),
      findsOneWidget,
    );
    expect(find.text('Progress is unavailable right now.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  UserAchievementDto achievement,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AchievementCard(achievement: achievement),
        ),
      ),
    ),
  );
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  required _MemoryTokenStore tokenStore,
  required _FakeResultRetryDrainer retryDrainer,
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
    retryDrainer: retryDrainer,
  );
  addTearDown(authCubit.close);
  addTearDown(invalidationController.close);
  addTearDown(apiClient.close);

  await authCubit.initialize();
  retryDrainer.userIds.clear();

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<LexRushBackendRepository>(
          create: (_) => LexRushBackendRepository(apiClient: apiClient),
        ),
        RepositoryProvider<ResultRetryDrainer>.value(value: retryDrainer),
      ],
      child: BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProfileScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollProfileDown(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
  await tester.pumpAndSettle();
}

Future<http.Response> _profileResponse(http.Request request) async {
  switch (request.url.path) {
    case '/auth/me':
      return http.Response(
        jsonEncode(<String, dynamic>{
          'userId': 'user-1',
          'email': 'user@example.com',
          'displayName': 'User',
        }),
        200,
      );
    case '/me/progress':
      return http.Response(
        jsonEncode(<String, dynamic>{
          'userId': 'user-1',
          'totalXp': 194,
          'currentStreak': 1,
          'longestStreak': 2,
          'lastTrainingDay': '2026-06-05',
          'sessionsCompleted': 6,
        }),
        200,
      );
    case '/me/skills':
      return http.Response(
        jsonEncode(<String, dynamic>{
          'userId': 'user-1',
          'skills': <Map<String, dynamic>>[
            <String, dynamic>{
              'skillId': 'punctuation',
              'level': 2,
              'masteryScore': 0.24,
              'accuracy': 0.4,
              'recentTrend': 'improving',
              'confidence': 0.35,
            },
          ],
        }),
        200,
      );
    case '/me/achievements':
      return http.Response(
        jsonEncode(<String, dynamic>{'achievements': <dynamic>[]}),
        200,
      );
    default:
      return http.Response('{}', 404);
  }
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

class _FakeResultRetryDrainer implements ResultRetryDrainer {
  final List<String> userIds = <String>[];

  @override
  Future<void> drain({required String userId}) async {
    userIds.add(userId);
  }
}
