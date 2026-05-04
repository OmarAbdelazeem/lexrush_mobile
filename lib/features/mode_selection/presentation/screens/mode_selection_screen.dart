import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/shared/application/services/game_registry_service.dart';
import 'package:lexrush/shared/domain/entities/game_definition.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';
import 'package:lexrush/shared/domain/entities/game_mode_codec.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final GameRegistryService registry = GameRegistryService.defaultRegistry();
    final List<GameDefinition> games = registry.listAll();
    debugPrint('[ModeSelectionScreen] rendering modes count=${games.length}');

    return PortraitShell(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Choose Mode',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Select your challenge',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Sharpen speed. Master words.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            ...games.asMap().entries.map((MapEntry<int, GameDefinition> entry) {
              final int index = entry.key;
              final GameDefinition game = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == games.length - 1 ? 0 : 12,
                ),
                child: _ModeCard(
                  title: game.title,
                  subtitle: game.description,
                  icon: _iconForMode(game.mode),
                  color: _colorForMode(game.mode),
                  isAvailable: !game.isLocked,
                  onTap: !game.isLocked
                      ? () {
                          debugPrint(
                            '[ModeSelectionScreen] selected mode=${game.id}',
                          );
                          context.go(
                            '${AppRoutes.preGame}/${GameModeCodec.toPath(game.mode)}',
                          );
                        }
                      : null,
                ),
              );
            }),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  IconData _iconForMode(GameMode mode) {
    switch (mode) {
      case GameMode.antonymRush:
        return Icons.local_fire_department_rounded;
      case GameMode.synonymStorm:
        return Icons.auto_awesome_rounded;
      case GameMode.definitionMatch:
        return Icons.menu_book_rounded;
      case GameMode.association:
        return Icons.hub_rounded;
    }
  }

  Color _colorForMode(GameMode mode) {
    switch (mode) {
      case GameMode.antonymRush:
        return AppColors.primary;
      case GameMode.synonymStorm:
        return AppColors.accent;
      case GameMode.definitionMatch:
        return AppColors.reward;
      case GameMode.association:
        return AppColors.primary;
    }
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isAvailable,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isAvailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isAvailable ? 1 : 0.55,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        color,
                        Color.lerp(color, Colors.white, 0.18)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isAvailable ? icon : Icons.lock_rounded,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (!isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Soon',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
