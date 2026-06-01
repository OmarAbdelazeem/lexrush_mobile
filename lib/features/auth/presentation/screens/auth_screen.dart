import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/auth/application/auth_cubit.dart';
import 'package:lexrush/features/auth/application/auth_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  bool _isRegistering = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    if (_isRegistering) {
      await context.read<AuthCubit>().register(
        email: email,
        password: password,
        displayName: _displayNameController.text.trim(),
      );
      return;
    }

    await context.read<AuthCubit>().login(email: email, password: password);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (AuthState previous, AuthState current) {
        return !previous.isAuthenticated && current.isAuthenticated;
      },
      listener: (BuildContext context, _) {
        if (context.canPop()) {
          context.pop();
        }
      },
      child: PortraitShell(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (BuildContext context, AuthState state) {
              final bool isLoading = state.status == AuthStatus.loading;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _isRegistering ? 'Create Account' : 'Sign In',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save XP, streaks, and skill progress.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (_isRegistering) ...<Widget>[
                    _AuthField(
                      controller: _displayNameController,
                      label: 'Display name',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _AuthField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _AuthField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (state.status == AuthStatus.error) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage ?? 'Authentication failed.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: Text(_isRegistering ? 'Create Account' : 'Sign In'),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() => _isRegistering = !_isRegistering);
                          },
                    child: Text(
                      _isRegistering
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account',
                    ),
                  ),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(labelText: label),
    );
  }
}
