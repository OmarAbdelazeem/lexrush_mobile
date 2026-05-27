class ApiAuthHeadersProvider {
  const ApiAuthHeadersProvider._({required this.devUserId});

  factory ApiAuthHeadersProvider.dev({String devUserId = 'dev-user-001'}) {
    return ApiAuthHeadersProvider._(devUserId: devUserId);
  }

  final String devUserId;

  Map<String, String> headers() {
    return <String, String>{'x-dev-user-id': devUserId};
  }
}
