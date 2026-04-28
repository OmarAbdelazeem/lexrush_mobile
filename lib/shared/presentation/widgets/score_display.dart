import 'package:flutter/material.dart';

class ScoreDisplay extends StatelessWidget {
  const ScoreDisplay({
    required this.score,
    super.key,
  });

  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text('Score', style: Theme.of(context).textTheme.bodyMedium),
        Text('$score', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
