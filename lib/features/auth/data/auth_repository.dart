import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/auth/token_store.dart';
import 'package:lexrush/core/network/api_client.dart';
import 'package:lexrush/core/network/request_auth_policy.dart';
import 'package:lexrush/features/auth/data/auth_dtos.dart';

class AuthRepository {
  const AuthRepository({
    required ApiClient apiClient,
    required TokenStore tokenStore,
  }) : _apiClient = apiClient,
       _tokenStore = tokenStore;

  final ApiClient _apiClient;
  final TokenStore _tokenStore;

  Future<AuthResponse> register(RegisterRequest request) async {
    final Map<String, dynamic> json = await _apiClient.post(
      '/auth/register',
      body: request.toJson(),
      authPolicy: RequestAuthPolicy.public,
    );
    final AuthResponse response = AuthResponse.fromJson(json);
    await _tokenStore.writeTokens(response.tokens);
    return response;
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final Map<String, dynamic> json = await _apiClient.post(
      '/auth/login',
      body: request.toJson(),
      authPolicy: RequestAuthPolicy.public,
    );
    final AuthResponse response = AuthResponse.fromJson(json);
    await _tokenStore.writeTokens(response.tokens);
    return response;
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final Map<String, dynamic> json = await _apiClient.post(
      '/auth/refresh',
      body: <String, dynamic>{'refreshToken': refreshToken},
      authPolicy: RequestAuthPolicy.public,
    );
    final AuthTokens tokens = AuthTokens.fromJson(json);
    await _tokenStore.writeTokens(tokens);
    return tokens;
  }

  Future<void> logout() async {
    final AuthTokens? tokens = await _tokenStore.readTokens();
    final String? refreshToken = tokens?.refreshToken;
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.post(
          '/auth/logout',
          body: <String, dynamic>{'refreshToken': refreshToken},
          authPolicy: RequestAuthPolicy.public,
        );
      }
    } finally {
      await _tokenStore.clearTokens();
    }
  }

  Future<AuthUser> me() async {
    final Map<String, dynamic> json = await _apiClient.get(
      '/auth/me',
      authPolicy: RequestAuthPolicy.requiredAuth,
    );
    return AuthUser.fromJson(json);
  }

  Future<bool> hasTokens() async => (await _tokenStore.readTokens()) != null;
}
