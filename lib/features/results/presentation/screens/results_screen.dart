import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lexrush/app/router/app_router.dart';
import 'package:lexrush/features/games/association/domain/entities/association_game_result.dart';
import 'package:lexrush/features/games/association/presentation/screens/association_results_screen.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';
import 'package:lexrush/features/games/commas/presentation/screens/commas_results_screen.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_game_result.dart';
import 'package:lexrush/features/games/sequencing_memory/presentation/screens/sequencing_memory_results_screen.dart';
import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';
import 'package:lexrush/shared/domain/entities/game_mode_codec.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/synced_result_extra.dart';
import 'package:lexrush/shared/presentation/widgets/base_results_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Object? routeExtra = GoRouterState.of(context).extra;
    final Object? extra = routeExtra is SyncedResultExtra
        ? routeExtra.result
        : routeExtra;
    final BackendResultSyncHandle? syncHandle = routeExtra is SyncedResultExtra
        ? routeExtra.syncHandle
        : null;

    Widget wrapWithHandle(Widget child) {
      final BackendResultSyncHandle? handle = syncHandle;
      if (handle == null) return child;
      return _SyncHandleDisposer(syncHandle: handle, child: child);
    }

    if (extra is AssociationGameResult) {
      debugPrint('[ResultsScreen] rendering association-result');
      return wrapWithHandle(
        AssociationResultsScreen(
          result: extra,
          syncHandle: syncHandle,
          onPlayAgain: () => context.go(
            '${AppRoutes.preGame}/${GameModeCodec.toPath(GameMode.association)}',
          ),
          onBackToModes: () => context.go(AppRoutes.modeSelection),
        ),
      );
    }
    if (extra is SequencingGameResult) {
      debugPrint('[ResultsScreen] rendering sequencing-memory-result');
      return wrapWithHandle(
        SequencingMemoryResultsScreen(
          result: extra,
          syncHandle: syncHandle,
          onPlayAgain: () => context.go(
            '${AppRoutes.preGame}/${GameModeCodec.toPath(GameMode.sequencingMemory)}',
          ),
          onBackToModes: () => context.go(AppRoutes.modeSelection),
        ),
      );
    }
    if (extra is CommasGameResult) {
      debugPrint('[ResultsScreen] rendering commas-result');
      return wrapWithHandle(
        CommasResultsScreen(
          result: extra,
          syncHandle: syncHandle,
          onPlayAgain: () => context.go(
            '${AppRoutes.preGame}/${GameModeCodec.toPath(GameMode.commas)}',
          ),
          onBackToModes: () => context.go(AppRoutes.modeSelection),
        ),
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

    return wrapWithHandle(
      BaseResultsScreen(
        result: extra,
        syncHandle: syncHandle,
        onPlayAgain: () => context.go(
          '${AppRoutes.preGame}/${GameModeCodec.toPath(GameMode.antonymRush)}',
        ),
        onBackToModes: () => context.go(AppRoutes.modeSelection),
      ),
    );
  }
}

class _SyncHandleDisposer extends StatefulWidget {
  const _SyncHandleDisposer({required this.syncHandle, required this.child});

  final BackendResultSyncHandle syncHandle;
  final Widget child;

  @override
  State<_SyncHandleDisposer> createState() => _SyncHandleDisposerState();
}

class _SyncHandleDisposerState extends State<_SyncHandleDisposer> {
  @override
  void dispose() {
    widget.syncHandle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
