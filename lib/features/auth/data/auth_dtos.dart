import 'package:lexrush/core/auth/auth_tokens.dart';

class AuthUser {
  const AuthUser({
    required this.userId,
    required this.email,
    required this.displayName,
    this.language,
    this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      language: json['language'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  final String userId;
  final String email;
  final String? displayName;
  final String? language;
  final String? createdAt;
}

class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    this.displayName,
  });

  final String email;
  final String password;
  final String? displayName;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'password': password,
      if (displayName != null && displayName!.isNotEmpty)
        'displayName': displayName,
    };
  }
}

class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'email': email, 'password': password};
  }
}

class AuthResponse {
  const AuthResponse({required this.tokens, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      tokens: AuthTokens.fromJson(json),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final AuthTokens tokens;
  final AuthUser user;
}
