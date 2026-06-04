import 'package:lexrush/core/network/api_exception.dart';

abstract final class ResultSyncErrorClassifier {
  static bool isRetryable(Object error) {
    if (error is! ApiException) return false;
    final int? statusCode = error.statusCode;
    return statusCode == null || statusCode >= 500;
  }

  static bool isTerminalSuccess(Object error) {
    return error is ApiException && error.isSessionAlreadyCompleted;
  }

  static bool isAuthRequired(Object error) {
    return error is ApiException && error.isAuthRequired;
  }

  static bool isValidationOrClientError(Object error) {
    if (error is! ApiException) return false;
    if (error.code == 'VALIDATION_ERROR') return true;
    final int? statusCode = error.statusCode;
    return statusCode != null && statusCode >= 400 && statusCode < 500;
  }
}
