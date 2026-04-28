import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';
import 'package:lexrush/shared/domain/entities/game_mode_codec.dart';

class PreGameScreen extends StatelessWidget {
  const PreGameScreen({
    required this.mode,
    super.key,
  });

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return PortraitShell(
      title: 'Ready',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Spacer(),
            Text(
              _titleForMode(mode),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '3 · 2 · 1 · GO',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Countdown behavior will be implemented in Stage 2.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go(
                '${AppRoutes.gameplay}/${GameModeCodec.toPath(mode)}',
              ),
              child: const Text('Enter Gameplay'),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForMode(GameMode mode) {
    switch (mode) {
      case GameMode.antonymRush:
        return 'Antonym Rush';
      case GameMode.synonymStorm:
        return 'Synonym Storm';
      case GameMode.definitionMatch:
        return 'Definition Match';
    }
  }
}
