import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class PortraitShell extends StatelessWidget {
  const PortraitShell({
    required this.child,
    this.title,
    super.key,
  });

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: <Widget>[
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Text(
                          title!,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
