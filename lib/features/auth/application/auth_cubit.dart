import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexrush/core/auth/auth_invalidation_controller.dart';
import 'package:lexrush/core/network/api_exception.dart';
import 'package:lexrush/features/auth/application/auth_state.dart';
import 'package:lexrush/features/auth/data/auth_dtos.dart';
import 'package:lexrush/features/auth/data/auth_repository.dart';
import 'package:lexrush/shared/application/services/offline_result_retry_coordinator.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required AuthRepository repository,
    required AuthInvalidationController invalidationController,
    ResultRetryDrainer? retryDrainer,
  }) : _repository = repository,
       _invalidationController = invalidationController,
       _retryDrainer = retryDrainer,
       super(const AuthState.initial()) {
    _invalidationSubscription = _invalidationController.stream.listen((_) {
      emit(const AuthState.unauthenticated());
    });
  }

  final AuthRepository _repository;
  final AuthInvalidationController _invalidationController;
  final ResultRetryDrainer? _retryDrainer;
  late final StreamSubscription<void> _invalidationSubscription;

  Future<void> initialize() async {
    final bool hasTokens = await _repository.hasTokens();
    if (!hasTokens) {
      emit(const AuthState.unauthenticated());
      return;
    }

    emit(const AuthState.loading());
    try {
      final AuthUser user = await _repository.me();
      emit(AuthState.authenticated(user: user));
      _drainPendingResults(user.userId);
    } on ApiException catch (error) {
      if (error.isInvalidRefreshToken || error.isUnauthorized) {
        await _repository.logout();
        emit(const AuthState.unauthenticated());
        return;
      }
      emit(const AuthState.authenticated());
    } on Object {
      // Keep stored tokens when startup validation cannot reach the backend.
      emit(const AuthState.authenticated());
    }
  }

  Future<void> login({required String email, required String password}) async {
    emit(AuthState.loading(user: state.user));
    try {
      final AuthResponse response = await _repository.login(
        LoginRequest(email: email, password: password),
      );
      emit(AuthState.authenticated(user: response.user));
      _drainPendingResults(response.user.userId);
    } on Object {
      emit(const AuthState.error('Sign in failed. Check your details.'));
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    emit(AuthState.loading(user: state.user));
    try {
      final AuthResponse response = await _repository.register(
        RegisterRequest(
          email: email,
          password: password,
          displayName: displayName,
        ),
      );
      emit(AuthState.authenticated(user: response.user));
      _drainPendingResults(response.user.userId);
    } on Object {
      emit(const AuthState.error('Could not create that account.'));
    }
  }

  Future<void> logout() async {
    emit(AuthState.loading(user: state.user));
    try {
      await _repository.logout();
    } on Object {
      // Local tokens are cleared by the repository even if backend logout fails.
    }
    emit(const AuthState.unauthenticated());
  }

  @override
  Future<void> close() async {
    await _invalidationSubscription.cancel();
    return super.close();
  }

  void _drainPendingResults(String? userId) {
    final ResultRetryDrainer? retryDrainer = _retryDrainer;
    if (retryDrainer == null || userId == null || userId.isEmpty) return;
    unawaited(retryDrainer.drain(userId: userId).catchError((_) {}));
  }
}
