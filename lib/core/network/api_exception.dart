class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  final int? statusCode;
  final String? code;
  final String message;
  final Object? cause;

  bool get isSessionAlreadyCompleted => code == 'SESSION_ALREADY_COMPLETED';
  bool get isUnauthorized => statusCode == 401 && code == 'UNAUTHORIZED';
  bool get isInvalidRefreshToken => code == 'INVALID_REFRESH_TOKEN';
  bool get isAuthRequired => code == 'AUTH_REQUIRED';

  @override
  String toString() {
    final String status = statusCode == null ? '' : 'HTTP $statusCode ';
    final String codeLabel = code == null ? '' : '$code: ';
    return 'ApiException: $status$codeLabel$message';
  }
}
