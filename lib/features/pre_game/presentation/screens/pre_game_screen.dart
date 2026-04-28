import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';
import 'package:lexrush/shared/domain/entities/game_mode_codec.dart';

class PreGameScreen extends StatefulWidget {
  const PreGameScreen({
    required this.mode,
    super.key,
  });

  final GameMode mode;

  @override
  State<PreGameScreen> createState() => _PreGameScreenState();
}

class _PreGameScreenState extends State<PreGameScreen> {
  int? _countdown;
  bool _showReady = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _showReady = false;
        _countdown = 3;
      });
      _tickCountdown();
    });
  }

  Future<void> _tickCountdown() async {
    while (mounted && _countdown != null && _countdown! > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _countdown = _countdown! - 1);
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    context.go('${AppRoutes.gameplay}/${GameModeCodec.toPath(widget.mode)}');
  }

  @override
  Widget build(BuildContext context) {
    return PortraitShell(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.25, end: 0.6),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.primary.withValues(alpha: value * 0.30),
                      AppColors.background,
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 28,
            left: 22,
            right: 22,
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_fire_department, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_titleForMode(widget.mode), style: Theme.of(context).textTheme.titleLarge),
                    Text('60 seconds • Fast focus', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: _showReady
                  ? Column(
                      key: const ValueKey<String>('ready'),
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('Ready?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 56)),
                        const SizedBox(height: 8),
                        Text('Get set to react fast', style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    )
                  : Text(
                      _countdown == 0 ? 'GO' : '${_countdown ?? ''}',
                      key: ValueKey<int?>(_countdown),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: 120,
                            color: _countdown == 0 ? AppColors.accent : AppColors.textPrimary,
                          ),
                    ),
            ),
          ),
        ],
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
