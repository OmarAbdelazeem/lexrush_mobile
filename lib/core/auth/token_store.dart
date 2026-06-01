import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lexrush/core/auth/auth_tokens.dart';

abstract interface class TokenStore {
  Future<AuthTokens?> readTokens();

  Future<void> writeTokens(AuthTokens tokens);

  Future<void> clearTokens();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const String _accessTokenKey = 'lexrush_access_token';
  static const String _refreshTokenKey = 'lexrush_refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> readTokens() async {
    final String? accessToken = await _storage.read(key: _accessTokenKey);
    final String? refreshToken = await _storage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) return null;
    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    await Future.wait(<Future<void>>[
      _storage.write(key: _accessTokenKey, value: tokens.accessToken),
      _storage.write(key: _refreshTokenKey, value: tokens.refreshToken),
    ]);
  }

  @override
  Future<void> clearTokens() async {
    await Future.wait(<Future<void>>[
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
