import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/core/auth/auth_invalidation_controller.dart';
import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/auth/application/auth_state.dart';
import 'package:lexrush/features/auth/data/auth_dtos.dart';
import 'package:lexrush/features/auth/data/auth_repository.dart';

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
