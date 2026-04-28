import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/features/onboarding/application/cubit/onboarding_flow_cubit.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  const _OnboardingSlide(this.title, this.description, this.icon, this.color);

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<_OnboardingSlide> _slides = const <_OnboardingSlide>[
    _OnboardingSlide(
      'Train Vocabulary Fast',
      'Master words through rapid-fire challenges.',
      Icons.bolt_rounded,
      AppColors.primary,
    ),
    _OnboardingSlide(
      'Improve Focus Daily',
      'Build concentration with quick 60-second sessions.',
      Icons.my_location_rounded,
      AppColors.accent,
    ),
    _OnboardingSlide(
      'Track Your Growth',
      'Review stats after each round and keep improving.',
      Icons.trending_up_rounded,
      AppColors.reward,
    ),
  ];

  int _currentIndex = 0;

  Future<void> _completeOnboarding(BuildContext context) async {
    debugPrint('[OnboardingScreen] complete onboarding');
    await context.read<OnboardingFlowCubit>().completeOnboarding();
    if (!context.mounted) return;
    context.go(AppRoutes.modeSelection);
  }

  @override
  Widget build(BuildContext context) {
    final _OnboardingSlide slide = _slides[_currentIndex];

    return PortraitShell(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _completeOnboarding(context),
                child: const Text('Skip'),
              ),
            ),
            const Spacer(),
            CircleAvatar(
              radius: 48,
              backgroundColor: slide.color.withValues(alpha: 0.22),
              child: Icon(slide.icon, size: 46, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 28),
            Text(
              slide.title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              slide.description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_slides.length, (int index) {
                final bool isActive = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_currentIndex < _slides.length - 1) {
                  debugPrint(
                    '[OnboardingScreen] slide advance $_currentIndex -> ${_currentIndex + 1}',
                  );
                  setState(() => _currentIndex += 1);
                  return;
                }
                _completeOnboarding(context);
              },
              child: Text(
                _currentIndex < _slides.length - 1 ? 'Continue' : 'Get Started',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
