import 'package:equatable/equatable.dart';
import 'package:lexrush/features/auth/data/auth_dtos.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  const AuthState({required this.status, this.user, this.errorMessage});

  const AuthState.initial() : this(status: AuthStatus.initial);

  const AuthState.loading({AuthUser? user})
    : this(status: AuthStatus.loading, user: user);

  const AuthState.authenticated({AuthUser? user})
    : this(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.error(String message)
    : this(status: AuthStatus.error, errorMessage: message);

  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => <Object?>[status, user, errorMessage];
}
