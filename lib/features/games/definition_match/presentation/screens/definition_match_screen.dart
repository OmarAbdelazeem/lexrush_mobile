import 'package:flutter/material.dart';
import 'package:lexrush/features/games/antonym_rush/presentation/screens/antonym_rush_screen.dart';

class DefinitionMatchScreen extends StatelessWidget {
  const DefinitionMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[DefinitionMatchScreen] reusing stable shared gameplay flow');
    return const AntonymRushScreen(
      gameTitle: 'Definition Match',
      promptLabel: 'Match definition',
    );
  }
}
