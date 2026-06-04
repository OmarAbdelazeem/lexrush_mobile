import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/core/auth/auth_invalidation_controller.dart';
import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/auth/application/auth_state.dart';
import 'package:lexrush/features/auth/data/auth_dtos.dart';
import 'package:lexrush/features/auth/data/auth_repository.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';

void main() {
  group('AuthCubit', () {
    test('startup keeps authenticated state when me fails offline', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        hasStoredTokens: true,
        meError: Exception('offline'),
      );
      final AuthInvalidationController invalidationController =
          AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: repository,
        invalidationController: invalidationController,
      );

      await cubit.initialize();

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(repository.logoutCalls, 0);

      await cubit.close();
      await invalidationController.close();
    });

    test('startup logs out on unrecoverable auth failure', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        hasStoredTokens: true,
        meError: const ApiException(
          statusCode: 401,
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired access token.',
        ),
      );
      final AuthInvalidationController invalidationController =
          AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: repository,
        invalidationController: invalidationController,
      );

      await cubit.initialize();

      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(repository.logoutCalls, 1);

      await cubit.close();
      await invalidationController.close();
    });

    test('login success authenticates with returned user', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository();
      final AuthInvalidationController invalidationController =
          AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: repository,
        invalidationController: invalidationController,
      );

      await cubit.login(email: 'test@example.com', password: 'password123');

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.user?.email, 'test@example.com');

      await cubit.close();
      await invalidationController.close();
    });

    test('login triggers pending result drain without blocking auth', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository();
      final _FakeResultRetryDrainer retryDrainer = _FakeResultRetryDrainer(
        drainCompleter: Completer<void>(),
      );
      final AuthInvalidationController invalidationController =
          AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: repository,
        invalidationController: invalidationController,
        retryDrainer: retryDrainer,
      );

      await cubit.login(email: 'test@example.com', password: 'password123');

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(retryDrainer.userIds, <String>['user-1']);

      retryDrainer.drainCompleter!.complete();
      await cubit.close();
      await invalidationController.close();
    });

    test('register triggers pending result drain', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository();
      final _FakeResultRetryDrainer retryDrainer = _FakeResultRetryDrainer();
      final AuthInvalidationController invalidationController =
          AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: repository,
        invalidationController: invalidationController,
        retryDrainer: retryDrainer,
      );

      await cubit.register(
        email: 'test@example.com',
        password: 'password123',
        displayName: 'Test',
      );

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(retryDrainer.userIds, <String>['user-1']);

      await cubit.close();
      await invalidationController.close();
    });

    test('startup with restored user triggers pending result drain', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        hasStoredTokens: true,
      );
      final _FakeResultRetryDrainer retryDrainer = _FakeResultRetryDrainer();
      final AuthInvalidationController invalidationController =
          AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: repository,
        invalidationController: invalidationController,
        retryDrainer: retryDrainer,
      );

      await cubit.initialize();

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(retryDrainer.userIds, <String>['user-1']);

      await cubit.close();
      await invalidationController.close();
    });

    test('drain failure does not undo successful login', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository();
      final _FakeResultRetryDrainer retryDrainer = _FakeResultRetryDrainer(
        drainError: Exception('queue unavailable'),
      );
      final AuthInvalidationController invalidationController =
          AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: repository,
        invalidationController: invalidationController,
        retryDrainer: retryDrainer,
      );

      await cubit.login(email: 'test@example.com', password: 'password123');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(retryDrainer.userIds, <String>['user-1']);

      await cubit.close();
      await invalidationController.close();
    });

    test('invalidation signal moves auth state to logged out', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository();
      final AuthInvalidationController invalidationController =
          AuthInvalidationController();
      final AuthCubit cubit = AuthCubit(
        repository: repository,
        invalidationController: invalidationController,
      );

      await cubit.login(email: 'test@example.com', password: 'password123');
      invalidationController.notifyInvalidated();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AuthStatus.unauthenticated);

      await cubit.close();
      await invalidationController.close();
    });
  });
}

class _FakeResultRetryDrainer implements ResultRetryDrainer {
  _FakeResultRetryDrainer({this.drainCompleter, this.drainError});

  final Completer<void>? drainCompleter;
  final Object? drainError;
  final List<String> userIds = <String>[];

  @override
  Future<void> drain({required String userId}) async {
    userIds.add(userId);
    final Object? error = drainError;
    if (error != null) throw error;
    final Completer<void>? completer = drainCompleter;
    if (completer != null) return completer.future;
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.hasStoredTokens = false, this.meError});

  final bool hasStoredTokens;
  final Object? meError;
  int logoutCalls = 0;

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    return const AuthTokens(accessToken: 'access-2', refreshToken: 'refresh-2');
  }

  @override
  Future<bool> hasTokens() async => hasStoredTokens;

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    return AuthResponse(
      tokens: const AuthTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      ),
      user: AuthUser(
        userId: 'user-1',
        email: request.email,
        displayName: 'Test',
      ),
    );
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }

  @override
  Future<AuthUser> me() async {
    final Object? error = meError;
    if (error != null) throw error;
    return const AuthUser(
      userId: 'user-1',
      email: 'test@example.com',
      displayName: 'Test',
    );
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    return AuthResponse(
      tokens: const AuthTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      ),
      user: AuthUser(
        userId: 'user-1',
        email: request.email,
        displayName: request.displayName,
      ),
    );
  }
}
