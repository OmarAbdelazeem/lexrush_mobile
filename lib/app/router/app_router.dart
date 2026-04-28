import 'package:go_router/go_router.dart';
import 'package:lexrush/features/games/antonym_rush/presentation/screens/antonym_rush_screen.dart';
import 'package:lexrush/features/games/definition_match/presentation/screens/definition_match_screen.dart';
import 'package:lexrush/features/games/synonym_storm/presentation/screens/synonym_storm_screen.dart';
import 'package:lexrush/features/mode_selection/presentation/screens/mode_selection_screen.dart';
import 'package:lexrush/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:lexrush/features/pre_game/presentation/screens/pre_game_screen.dart';
import 'package:lexrush/features/results/presentation/screens/results_screen.dart';
import 'package:lexrush/features/splash/presentation/screens/splash_screen.dart';
import 'package:lexrush/shared/domain/entities/game_mode.dart';
import 'package:lexrush/shared/domain/entities/game_mode_codec.dart';

abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String modeSelection = '/mode-selection';
  static const String preGame = '/pre-game';
  static const String gameplay = '/gameplay';
  static const String results = '/results';
}

abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: <GoRoute>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.modeSelection,
        builder: (context, state) => const ModeSelectionScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.preGame}/:mode',
        builder: (context, state) {
          final GameMode? mode = GameModeCodec.fromPath(
            state.pathParameters['mode'] ?? '',
          );
          return PreGameScreen(mode: mode ?? GameMode.antonymRush);
        },
      ),
      GoRoute(
        path: '${AppRoutes.gameplay}/:mode',
        builder: (context, state) {
          final GameMode? mode = GameModeCodec.fromPath(
            state.pathParameters['mode'] ?? '',
          );
          switch (mode) {
            case GameMode.synonymStorm:
              return const SynonymStormScreen();
            case GameMode.definitionMatch:
              return const DefinitionMatchScreen();
            case GameMode.antonymRush:
            case null:
              return const AntonymRushScreen();
          }
        },
      ),
      GoRoute(
        path: AppRoutes.results,
        builder: (context, state) => const ResultsScreen(),
      ),
    ],
  );
}
