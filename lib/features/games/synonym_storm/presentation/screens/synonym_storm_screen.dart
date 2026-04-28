import 'package:flutter/material.dart';
import 'package:lexrush/features/games/antonym_rush/presentation/screens/antonym_rush_screen.dart';

class SynonymStormScreen extends StatelessWidget {
  const SynonymStormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[SynonymStormScreen] reusing stable shared gameplay flow');
    return const AntonymRushScreen(
      gameTitle: 'Synonym Storm',
      promptLabel: 'Find synonym',
    );
  }
}
