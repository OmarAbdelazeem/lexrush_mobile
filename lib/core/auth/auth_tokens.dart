class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}
