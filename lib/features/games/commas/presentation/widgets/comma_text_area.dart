import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_token.dart';
import 'package:lexrush/features/games/commas/presentation/widgets/comma_gap_detector.dart';

class CommaTextArea extends StatelessWidget {
  const CommaTextArea({
    required this.tokens,
    required this.flashGapAfterTokenIndex,
    required this.onGapTap,
    this.showDebugGapHitboxes = false,
    super.key,
  });

  final List<CommaToken> tokens;
  final int? flashGapAfterTokenIndex;
  final ValueChanged<int> onGapTap;
  final bool showDebugGapHitboxes;

  @override
  Widget build(BuildContext context) {
    final TextStyle? wordStyle = Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontSize: 29, height: 1.55, color: AppColors.textPrimary);
    final List<Widget> children = tokens.map((CommaToken token) {
      final bool hasGap = token.index < tokens.length - 1;
      return _TokenWithGap(
        token: token,
        wordStyle: wordStyle,
        hasGap: hasGap,
        isFlashingWrong: flashGapAfterTokenIndex == token.index,
        showDebugGapHitboxes: showDebugGapHitboxes,
        onGapTap: onGapTap,
      );
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Wrap(
        spacing: 0,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

class _TokenWithGap extends StatelessWidget {
  const _TokenWithGap({
    required this.token,
    required this.wordStyle,
    required this.hasGap,
    required this.isFlashingWrong,
    required this.showDebugGapHitboxes,
    required this.onGapTap,
  });

  final CommaToken token;
  final TextStyle? wordStyle;
  final bool hasGap;
  final bool isFlashingWrong;
  final bool showDebugGapHitboxes;
  final ValueChanged<int> onGapTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(token.text, style: wordStyle),
          if (hasGap)
            CommaGapDetector(
              afterTokenIndex: token.index,
              commaPlaced: token.commaPlacedAfter,
              isFlashingWrong: isFlashingWrong,
              showDebugHitboxes: kDebugMode && showDebugGapHitboxes,
              onTap: onGapTap,
            ),
        ],
      ),
    );
  }
}
