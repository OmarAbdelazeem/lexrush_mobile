import 'package:flutter/material.dart';
import 'package:lexrush/core/widgets/portrait_shell.dart';

class GameShell extends StatelessWidget {
  const GameShell({
    required this.hud,
    required this.playfield,
    required this.footer,
    this.title,
    super.key,
  });

  final Widget hud;
  final Widget playfield;
  final Widget footer;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return PortraitShell(
      title: title,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: hud,
          ),
          Expanded(child: playfield),
          Padding(
            padding: const EdgeInsets.all(16),
            child: footer,
          ),
        ],
      ),
    );
  }
}
