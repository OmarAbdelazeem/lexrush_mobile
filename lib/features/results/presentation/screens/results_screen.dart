import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/features/games/association/domain/entities/association_game_result.dart';
import 'package:lexrush/features/games/association/presentation/screens/association_results_screen.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';
import 'package:lexrush/shared/domain/entities/game_mode_codec.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/presentation/widgets/base_results_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Object? extra = GoRouterState.of(context).extra;
    if (extra is AssociationGameResult) {
      debugPrint('[ResultsScreen] rendering association-result');
      return AssociationResultsScreen(
        result: extra,
        onPlayAgain: () => context.go(
          '${AppRoutes.preGame}/${GameModeCodec.toPath(GameMode.association)}',
        ),
        onBackToModes: () => context.go(AppRoutes.modeSelection),
      );
    }
    if (extra is! GameResult) {
      debugPrint(
        '[ResultsScreen] missing GameResult -> redirect modeSelection',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppRoutes.modeSelection);
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    debugPrint('[ResultsScreen] rendering session-result');

    return BaseResultsScreen(
      result: extra,
      onPlayAgain: () => context.go(
        '${AppRoutes.preGame}/${GameModeCodec.toPath(GameMode.antonymRush)}',
      ),
      onBackToModes: () => context.go(AppRoutes.modeSelection),
    );
  }
}
