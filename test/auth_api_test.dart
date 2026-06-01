import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexrush/core/auth/auth_invalidation_controller.dart';
import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/auth/token_store.dart';
import 'package:lexrush/core/network/api_auth_headers_provider.dart';
import 'package:lexrush/core/network/api_client.dart';
import 'package:lexrush/core/network/api_config.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/core/network/request_auth_policy.dart';
import 'package:lexrush/features/auth/data/auth_dtos.dart';
import 'package:lexrush/features/auth/data/auth_repository.dart';

void main() {
  group('ApiClient auth policies', () {
    test('public requests omit Authorization and do not refresh', () async {
      final _FakeTokenStore tokenStore = _FakeTokenStore(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      int refreshCalls = 0;
      final ApiClient client = _client(
        tokenStore: tokenStore,
        handler: (http.Request request) async {
          if (request.url.path == '/auth/refresh') refreshCalls += 1;
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response(
            jsonEncode(<String, dynamic>{
              'error': <String, dynamic>{
                'code': 'UNAUTHORIZED',
                'message': 'Nope.',
              },
            }),
            401,
          );
        },
      );

      await expectLater(
        client.get('/health', authPolicy: RequestAuthPolicy.public),
        throwsA(isA<ApiException>()),
      );
      expect(refreshCalls, 0);
    });

    test('optional auth sends bearer only when available', () async {
      final List<String?> authorizations = <String?>[];
      final _FakeTokenStore tokenStore = _FakeTokenStore();
      final ApiClient client = _client(
        tokenStore: tokenStore,
        handler: (http.Request request) async {
          authorizations.add(request.headers['Authorization']);
          return http.Response('{}', 200);
        },
      );

      await client.get('/games', authPolicy: RequestAuthPolicy.optionalAuth);
      await tokenStore.writeTokens(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      await client.get('/games', authPolicy: RequestAuthPolicy.optionalAuth);

      expect(authorizations, <String?>[null, 'Bearer access-1']);
    });

    test('required auth without access token fails locally', () async {
      final ApiClient client = _client(
        tokenStore: _FakeTokenStore(),
        handler: (_) async => http.Response('{}', 200),
      );

      await expectLater(
        client.get('/me/progress', authPolicy: RequestAuthPolicy.requiredAuth),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.isAuthRequired,
            'isAuthRequired',
            isTrue,
          ),
        ),
      );
    });

    test(
      'required auth refreshes once, persists rotated tokens, and retries',
      () async {
        final _FakeTokenStore tokenStore = _FakeTokenStore(
          const AuthTokens(
            accessToken: 'old-access',
            refreshToken: 'old-refresh',
          ),
        );
        int refreshCalls = 0;
        final List<String?> protectedAuthorizations = <String?>[];
        final ApiClient client = _client(
          tokenStore: tokenStore,
          handler: (http.Request request) async {
            if (request.url.path == '/auth/refresh') {
              refreshCalls += 1;
              expect(jsonDecode(request.body), <String, dynamic>{
                'refreshToken': 'old-refresh',
              });
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                }),
                200,
              );
            }

            protectedAuthorizations.add(request.headers['Authorization']);
            if (request.headers['Authorization'] == 'Bearer old-access') {
              return _unauthorized();
            }
            return http.Response('{}', 200);
          },
        );

        await client.get(
          '/me/progress',
          authPolicy: RequestAuthPolicy.requiredAuth,
        );

        expect(refreshCalls, 1);
        expect(protectedAuthorizations, <String?>[
          'Bearer old-access',
          'Bearer new-access',
        ]);
        expect(tokenStore.tokens?.accessToken, 'new-access');
        expect(tokenStore.tokens?.refreshToken, 'new-refresh');
      },
    );

    test('concurrent 401s share one rotating refresh call', () async {
      final _FakeTokenStore tokenStore = _FakeTokenStore(
        const AuthTokens(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        ),
      );
      int refreshCalls = 0;
      final ApiClient client = _client(
        tokenStore: tokenStore,
        handler: (http.Request request) async {
          if (request.url.path == '/auth/refresh') {
            refreshCalls += 1;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return http.Response(
              jsonEncode(<String, dynamic>{
                'accessToken': 'new-access',
                'refreshToken': 'new-refresh',
              }),
              200,
            );
          }

          if (request.headers['Authorization'] == 'Bearer old-access') {
            return _unauthorized();
          }
          return http.Response('{}', 200);
        },
      );

      await Future.wait(<Future<Map<String, dynamic>>>[
        client.get('/me/progress', authPolicy: RequestAuthPolicy.requiredAuth),
        client.get('/me/skills', authPolicy: RequestAuthPolicy.requiredAuth),
      ]);

      expect(refreshCalls, 1);
      expect(tokenStore.tokens?.refreshToken, 'new-refresh');
    });

    test(
      'invalid refresh token clears tokens and notifies auth invalidated',
      () async {
        final _FakeTokenStore tokenStore = _FakeTokenStore(
          const AuthTokens(
            accessToken: 'old-access',
            refreshToken: 'old-refresh',
          ),
        );
        final AuthInvalidationController invalidationController =
            AuthInvalidationController();
        int invalidations = 0;
        final Stream<void> invalidatedStream = invalidationController.stream;
        final subscription = invalidatedStream.listen(
          (_) => invalidations += 1,
        );
        final ApiClient client = _client(
          tokenStore: tokenStore,
          onAuthInvalidated: invalidationController.notifyInvalidated,
          handler: (http.Request request) async {
            if (request.url.path == '/auth/refresh') {
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'error': <String, dynamic>{
                    'code': 'INVALID_REFRESH_TOKEN',
                    'message': 'Refresh token is invalid or expired.',
                  },
                }),
                401,
              );
            }
            return _unauthorized();
          },
        );

        await expectLater(
          client.get(
            '/me/progress',
            authPolicy: RequestAuthPolicy.requiredAuth,
          ),
          throwsA(isA<ApiException>()),
        );
        await Future<void>.delayed(Duration.zero);

        expect(tokenStore.tokens, isNull);
        expect(invalidations, 1);
        await subscription.cancel();
        await invalidationController.close();
      },
    );
  });

  group('AuthRepository', () {
    test('login stores returned tokens and user', () async {
      final _FakeTokenStore tokenStore = _FakeTokenStore();
      final AuthRepository repository = AuthRepository(
        apiClient: _client(
          tokenStore: tokenStore,
          handler: (_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'accessToken': 'access-1',
              'refreshToken': 'refresh-1',
              'user': <String, dynamic>{
                'userId': 'user-1',
                'email': 'test@example.com',
                'displayName': 'Test',
              },
            }),
            200,
          ),
        ),
        tokenStore: tokenStore,
      );

      final AuthResponse response = await repository.login(
        const LoginRequest(email: 'test@example.com', password: 'password123'),
      );

      expect(response.user.email, 'test@example.com');
      expect(tokenStore.tokens?.accessToken, 'access-1');
      expect(tokenStore.tokens?.refreshToken, 'refresh-1');
    });

    test('logout clears local tokens when backend logout fails', () async {
      final _FakeTokenStore tokenStore = _FakeTokenStore(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      final AuthRepository repository = AuthRepository(
        apiClient: _client(
          tokenStore: tokenStore,
          handler: (_) async {
            throw http.ClientException('offline');
          },
        ),
        tokenStore: tokenStore,
      );

      await expectLater(repository.logout(), throwsA(isA<ApiException>()));
      expect(tokenStore.tokens, isNull);
    });

    test('logout clears local tokens when no refresh token exists', () async {
      final _FakeTokenStore tokenStore = _FakeTokenStore();
      final AuthRepository repository = AuthRepository(
        apiClient: _client(
          tokenStore: tokenStore,
          handler: (_) async => http.Response('', 200),
        ),
        tokenStore: tokenStore,
      );

      await repository.logout();

      expect(tokenStore.clearCount, 1);
    });
  });
}

ApiClient _client({
  required _FakeTokenStore tokenStore,
  required Future<http.Response> Function(http.Request request) handler,
  void Function()? onAuthInvalidated,
}) {
  return ApiClient(
    config: const ApiConfig(baseUrl: 'http://example.test'),
    tokenStore: tokenStore,
    authHeadersProvider: ApiAuthHeadersProvider(tokenStore: tokenStore),
    httpClient: MockClient(handler),
    onAuthInvalidated: onAuthInvalidated,
  );
}

http.Response _unauthorized() {
  return http.Response(
    jsonEncode(<String, dynamic>{
      'error': <String, dynamic>{
        'code': 'UNAUTHORIZED',
        'message': 'Invalid or expired access token.',
      },
    }),
    401,
  );
}

class _FakeTokenStore implements TokenStore {
  _FakeTokenStore([this.tokens]);

  AuthTokens? tokens;
  int clearCount = 0;

  @override
  Future<void> clearTokens() async {
    clearCount += 1;
    tokens = null;
  }

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    this.tokens = tokens;
  }
}
