import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/features/games/association/domain/entities/association_game_result.dart';
import 'package:lexrush/features/games/association/presentation/screens/association_results_screen.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';
import 'package:lexrush/features/games/commas/presentation/screens/commas_results_screen.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_game_result.dart';
import 'package:lexrush/features/games/sequencing_memory/presentation/screens/sequencing_memory_results_screen.dart';
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
    if (extra is SequencingGameResult) {
      debugPrint('[ResultsScreen] rendering sequencing-memory-result');
      return SequencingMemoryResultsScreen(
        result: extra,
        onPlayAgain: () => context.go(
          '${AppRoutes.preGame}/${GameModeCodec.toPath(GameMode.sequencingMemory)}',
        ),
        onBackToModes: () => context.go(AppRoutes.modeSelection),
      );
    }
    if (extra is CommasGameResult) {
      debugPrint('[ResultsScreen] rendering commas-result');
      return CommasResultsScreen(
        result: extra,
        onPlayAgain: () => context.go(
          '${AppRoutes.preGame}/${GameModeCodec.toPath(GameMode.commas)}',
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
