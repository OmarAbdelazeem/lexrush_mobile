import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/auth/token_store.dart';
import 'package:lexrush/core/network/api_auth_headers_provider.dart';
import 'package:lexrush/core/network/api_config.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/core/network/request_auth_policy.dart';
import 'package:lexrush/shared/data/backend/api_error_envelope.dart';

typedef AuthInvalidatedCallback = void Function();

class ApiClient {
  ApiClient({
    required ApiConfig config,
    required TokenStore tokenStore,
    required ApiAuthHeadersProvider authHeadersProvider,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 8),
    AuthInvalidatedCallback? onAuthInvalidated,
  }) : _config = config,
       _tokenStore = tokenStore,
       _authHeadersProvider = authHeadersProvider,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout,
       _onAuthInvalidated = onAuthInvalidated;

  final ApiConfig _config;
  final TokenStore _tokenStore;
  final ApiAuthHeadersProvider _authHeadersProvider;
  final http.Client _httpClient;
  final Duration _timeout;
  final AuthInvalidatedCallback? _onAuthInvalidated;
  Future<AuthTokens>? _refreshInFlight;

  Future<bool> hasAccessToken() async {
    final AuthTokens? tokens = await _tokenStore.readTokens();
    return tokens?.accessToken.isNotEmpty ?? false;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    RequestAuthPolicy authPolicy = RequestAuthPolicy.public,
  }) async {
    final http.Response response = await _sendWithAuthPolicy(
      authPolicy: authPolicy,
      request: (Map<String, String> headers) {
        return _httpClient.get(_uri(path), headers: headers);
      },
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    RequestAuthPolicy authPolicy = RequestAuthPolicy.public,
  }) async {
    final String? encodedBody = body == null ? null : jsonEncode(body);
    final http.Response response = await _sendWithAuthPolicy(
      authPolicy: authPolicy,
      request: (Map<String, String> headers) {
        return _httpClient.post(
          _uri(path),
          headers: headers,
          body: encodedBody,
        );
      },
    );
    return _decodeResponse(response);
  }

  void close() => _httpClient.close();

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException catch (error) {
      throw ApiException(message: 'Request timed out.', cause: error);
    } on http.ClientException catch (error) {
      throw ApiException(message: error.message, cause: error);
    } on Object catch (error) {
      throw ApiException(message: 'Network request failed.', cause: error);
    }
  }

  Future<http.Response> _sendWithAuthPolicy({
    required RequestAuthPolicy authPolicy,
    required Future<http.Response> Function(Map<String, String> headers)
    request,
  }) async {
    final Map<String, String> headers = await _headers(authPolicy);
    final http.Response response = await _send(() => request(headers));
    if (authPolicy != RequestAuthPolicy.requiredAuth) {
      return response;
    }

    if (response.statusCode != 401) {
      return response;
    }

    final ApiException authError = _exceptionFromResponse(response);
    if (!authError.isUnauthorized) {
      return response;
    }

    try {
      await _refreshTokensSingleFlight();
    } on ApiException catch (error) {
      if (error.isInvalidRefreshToken) {
        await _tokenStore.clearTokens();
        _onAuthInvalidated?.call();
      }
      rethrow;
    }

    final Map<String, String> retryHeaders = await _headers(
      RequestAuthPolicy.requiredAuth,
    );
    return _send(() => request(retryHeaders));
  }

  Future<AuthTokens> _refreshTokensSingleFlight() {
    final Future<AuthTokens>? inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final Future<AuthTokens> refresh = _refreshTokens();
    _refreshInFlight = refresh;
    refresh.then(
      (_) {
        if (identical(_refreshInFlight, refresh)) {
          _refreshInFlight = null;
        }
      },
      onError: (_) {
        if (identical(_refreshInFlight, refresh)) {
          _refreshInFlight = null;
        }
      },
    );
    return refresh;
  }

  Future<AuthTokens> _refreshTokens() async {
    final AuthTokens? tokens = await _tokenStore.readTokens();
    final String? refreshToken = tokens?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        code: 'INVALID_REFRESH_TOKEN',
        message: 'Refresh token is invalid or expired.',
      );
    }

    final http.Response response = await _send(() {
      return _httpClient.post(
        _uri('/auth/refresh'),
        headers: _baseHeaders(),
        body: jsonEncode(<String, dynamic>{'refreshToken': refreshToken}),
      );
    });

    final Map<String, dynamic> body = _decodeResponse(response);
    final AuthTokens rotatedTokens = AuthTokens.fromJson(body);
    await _tokenStore.writeTokens(rotatedTokens);
    return rotatedTokens;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionFromResponse(response);
    }

    final Object? decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException catch (error) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Invalid JSON response.',
        cause: error,
      );
    }
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  ApiException _exceptionFromResponse(http.Response response) {
    try {
      final Object? decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final Map<String, dynamic> body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final ApiErrorEnvelope envelope = ApiErrorEnvelope.fromJson(body);
      return ApiException(
        statusCode: response.statusCode,
        code: envelope.code,
        message: envelope.message,
      );
    } on FormatException catch (error) {
      return ApiException(
        statusCode: response.statusCode,
        message: 'Invalid JSON response.',
        cause: error,
      );
    }
  }

  Uri _uri(String path) {
    final String baseUrl = _config.baseUrl.endsWith('/')
        ? _config.baseUrl.substring(0, _config.baseUrl.length - 1)
        : _config.baseUrl;
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Map<String, String> _baseHeaders() {
    return <String, String>{'Content-Type': 'application/json'};
  }

  Future<Map<String, String>> _headers(RequestAuthPolicy authPolicy) async {
    final Map<String, String> headers = _baseHeaders();
    if (authPolicy == RequestAuthPolicy.public) return headers;

    final Map<String, String> authHeaders = await _authHeadersProvider
        .authorizationHeaders();
    if (authHeaders.isEmpty && authPolicy == RequestAuthPolicy.requiredAuth) {
      throw const ApiException(
        code: 'AUTH_REQUIRED',
        message: 'Sign in required.',
      );
    }

    return <String, String>{...headers, ...authHeaders};
  }
}
