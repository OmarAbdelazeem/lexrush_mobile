class ApiErrorEnvelope {
  const ApiErrorEnvelope({required this.code, required this.message});

  factory ApiErrorEnvelope.fromJson(Map<String, dynamic> json) {
    final Object? error = json['error'];
    if (error is Map<String, dynamic>) {
      return ApiErrorEnvelope(
        code: error['code'] as String? ?? 'UNKNOWN_ERROR',
        message: error['message'] as String? ?? 'Request failed.',
      );
    }
    return const ApiErrorEnvelope(
      code: 'UNKNOWN_ERROR',
      message: 'Request failed.',
    );
  }

  final String code;
  final String message;
}
