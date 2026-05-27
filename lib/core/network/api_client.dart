import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lexrush/core/network/api_auth_headers_provider.dart';
import 'package:lexrush/core/network/api_config.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/shared/data/backend/api_error_envelope.dart';

class ApiClient {
  ApiClient({
    required ApiConfig config,
    required ApiAuthHeadersProvider authHeadersProvider,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 8),
  }) : _config = config,
       _authHeadersProvider = authHeadersProvider,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final ApiConfig _config;
  final ApiAuthHeadersProvider _authHeadersProvider;
  final http.Client _httpClient;
  final Duration _timeout;

  Future<Map<String, dynamic>> get(String path) async {
    final http.Response response = await _send(
      () => _httpClient.get(_uri(path), headers: _headers()),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final http.Response response = await _send(
      () => _httpClient.post(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
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

  Map<String, dynamic> _decodeResponse(http.Response response) {
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
    final Map<String, dynamic> body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final ApiErrorEnvelope envelope = ApiErrorEnvelope.fromJson(body);
      throw ApiException(
        statusCode: response.statusCode,
        code: envelope.code,
        message: envelope.message,
      );
    }

    return body;
  }

  Uri _uri(String path) {
    final String baseUrl = _config.baseUrl.endsWith('/')
        ? _config.baseUrl.substring(0, _config.baseUrl.length - 1)
        : _config.baseUrl;
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Map<String, String> _headers() {
    return <String, String>{
      'Content-Type': 'application/json',
      ..._authHeadersProvider.headers(),
    };
  }
}
