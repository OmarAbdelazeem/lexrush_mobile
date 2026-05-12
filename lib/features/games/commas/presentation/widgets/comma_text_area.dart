import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_token.dart';
import 'package:lexrush/features/games/commas/presentation/widgets/comma_gap_detector.dart';

class CommaTextArea extends StatefulWidget {
  const CommaTextArea({
    required this.tokens,
    required this.flashGapAfterTokenIndex,
    required this.sentenceCompletePulse,
    required this.onGapTap,
    this.difficulty = CommaDifficulty.medium,
    this.showDebugGapHitboxes = false,
    super.key,
  });

  final List<CommaToken> tokens;
  final int? flashGapAfterTokenIndex;
  final bool sentenceCompletePulse;
  final ValueChanged<int> onGapTap;
  final CommaDifficulty difficulty;
  final bool showDebugGapHitboxes;

  @override
  State<CommaTextArea> createState() => _CommaTextAreaState();
}

class _CommaTextAreaState extends State<CommaTextArea> {
  int? _lastPlacedGapIndex;
  int _placementPulse = 0;

  @override
  void didUpdateWidget(covariant CommaTextArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<int> currentPlacedIndexes = _placedIndexes(widget.tokens);
    final Set<int> previousPlacedIndexes = _placedIndexes(oldWidget.tokens);
    final Set<int> newlyPlaced = currentPlacedIndexes.difference(
      previousPlacedIndexes,
    );

    if (newlyPlaced.isNotEmpty) {
      _lastPlacedGapIndex = newlyPlaced.last;
      _placementPulse++;
    } else if (currentPlacedIndexes.isEmpty) {
      _lastPlacedGapIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int tokenCount = widget.tokens.length;
    final bool longPrompt = tokenCount > 18;
    final bool mediumPrompt = tokenCount > 10;
    final bool compactPrompt = tokenCount > 7;
    final double fontSize = switch (widget.difficulty) {
      CommaDifficulty.hard => longPrompt ? 21 : 23,
      CommaDifficulty.medium => mediumPrompt ? 24 : 27,
      CommaDifficulty.beginner => compactPrompt ? 28 : 31,
    };
    final TextStyle wordStyle = Theme.of(context).textTheme.headlineSmall!
        .copyWith(
          fontSize: fontSize,
          height: longPrompt ? 1.34 : 1.38,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0,
        );
    final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
      10,
      longPrompt ? 10 : 12,
      10,
      longPrompt ? 10 : 12,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: contentPadding,
      decoration: BoxDecoration(
        color: widget.sentenceCompletePulse
            ? AppColors.reward.withValues(alpha: 0.06)
            : AppColors.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.sentenceCompletePulse
              ? AppColors.reward.withValues(alpha: 0.42)
              : AppColors.accent.withValues(alpha: 0.16),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color:
                (widget.sentenceCompletePulse
                        ? AppColors.reward
                        : AppColors.accent)
                    .withValues(
                      alpha: widget.sentenceCompletePulse ? 0.16 : 0.10,
                    ),
            blurRadius: widget.sentenceCompletePulse ? 34 : 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return _MeasuredCommaProse(
            tokens: widget.tokens,
            maxWidth: constraints.maxWidth,
            textStyle: wordStyle,
            flashGapAfterTokenIndex: widget.flashGapAfterTokenIndex,
            lastPlacedGapIndex: _lastPlacedGapIndex,
            placementPulse: _placementPulse,
            sentenceCompletePulse: widget.sentenceCompletePulse,
            difficulty: widget.difficulty,
            showDebugGapHitboxes: widget.showDebugGapHitboxes,
            onGapTap: widget.onGapTap,
          );
        },
      ),
    );
  }

  Set<int> _placedIndexes(List<CommaToken> tokens) {
    return tokens
        .where((CommaToken token) => token.commaPlacedAfter)
        .map((CommaToken token) => token.index)
        .toSet();
  }
}

class _MeasuredCommaProse extends StatefulWidget {
  const _MeasuredCommaProse({
    required this.tokens,
    required this.maxWidth,
    required this.textStyle,
    required this.flashGapAfterTokenIndex,
    required this.lastPlacedGapIndex,
    required this.placementPulse,
    required this.sentenceCompletePulse,
    required this.difficulty,
    required this.showDebugGapHitboxes,
    required this.onGapTap,
  });

  final List<CommaToken> tokens;
  final double maxWidth;
  final TextStyle textStyle;
  final int? flashGapAfterTokenIndex;
  final int? lastPlacedGapIndex;
  final int placementPulse;
  final bool sentenceCompletePulse;
  final CommaDifficulty difficulty;
  final bool showDebugGapHitboxes;
  final ValueChanged<int> onGapTap;

  @override
  State<_MeasuredCommaProse> createState() => _MeasuredCommaProseState();
}

class _MeasuredCommaProseState extends State<_MeasuredCommaProse> {
  _MeasuredLayout? _layout;
  _LayoutSignature? _signature;

  @override
  Widget build(BuildContext context) {
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    final _LayoutSignature signature = _LayoutSignature(
      text: _displayText(widget.tokens),
      placedIndexes: _placedIndexes(widget.tokens),
      maxWidth: widget.maxWidth,
      textStyle: widget.textStyle,
      textScaler: textScaler,
      direction: direction,
    );

    if (_layout == null || _signature != signature) {
      _signature = signature;
      _layout = _measureLayout(signature, widget.tokens);
    }

    final _MeasuredLayout layout = _layout!;
    final bool debugVisible = kDebugMode && widget.showDebugGapHitboxes;

    return SizedBox(
      width: widget.maxWidth,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (final _GapLayout gap in layout.gaps)
            _GapAffordance(gap: gap, difficulty: widget.difficulty),
          RichText(
            text: layout.textSpan,
            textScaler: textScaler,
            textDirection: direction,
          ),
          if (widget.sentenceCompletePulse)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: const ValueKey<String>('sentence-complete-snap'),
                  tween: Tween<double>(begin: 1, end: 0),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.reward.withValues(
                            alpha: 0.30 * value,
                          ),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.reward.withValues(
                              alpha: 0.18 * value,
                            ),
                            blurRadius: 24 * value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          if (widget.sentenceCompletePulse)
            _SentenceCompleteBurst(gaps: layout.gaps),
          for (final _GapLayout gap in layout.gaps)
            Positioned.fromRect(
              rect: gap.hitRect,
              child: CommaGapDetector(
                afterTokenIndex: gap.afterTokenIndex,
                isFlashingWrong:
                    widget.flashGapAfterTokenIndex == gap.afterTokenIndex,
                showDebugHitboxes: debugVisible,
                width: gap.hitRect.width,
                height: gap.hitRect.height,
                onTap: widget.onGapTap,
              ),
            ),
          if (widget.flashGapAfterTokenIndex != null)
            _LocalWrongFeedback(
              gap: layout.gapFor(widget.flashGapAfterTokenIndex),
              pulseKey: widget.flashGapAfterTokenIndex!,
            ),
          if (widget.lastPlacedGapIndex != null)
            _LocalCorrectFeedback(
              gap: layout.gapFor(widget.lastPlacedGapIndex),
              pulseKey: widget.placementPulse,
            ),
        ],
      ),
    );
  }

  _MeasuredLayout _measureLayout(
    _LayoutSignature signature,
    List<CommaToken> tokens,
  ) {
    final TextSpan textSpan = _buildTextSpan(tokens, signature.textStyle);
    final TextPainter painter = TextPainter(
      text: textSpan,
      textDirection: signature.direction,
      textScaler: signature.textScaler,
      strutStyle: StrutStyle.fromTextStyle(signature.textStyle),
    )..layout(maxWidth: signature.maxWidth);

    final Map<int, int> gapOffsets = _gapTextOffsets(tokens);
    final List<_GapLayout> gaps = gapOffsets.entries.map((entry) {
      final Offset caret = painter.getOffsetForCaret(
        TextPosition(offset: entry.value),
        Rect.zero,
      );
      final TextRange lineRange = painter.getLineBoundary(
        TextPosition(offset: entry.value),
      );
      final List<TextBox> lineBoxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: lineRange.start, extentOffset: lineRange.end),
      );
      final TextBox? lineBox = lineBoxes.isEmpty ? null : lineBoxes.first;
      final double lineHeight = math.max(
        painter.preferredLineHeight,
        (lineBox?.bottom ?? painter.preferredLineHeight) - (lineBox?.top ?? 0),
      );
      final double top = math.max(0, (lineBox?.top ?? caret.dy) - 6);
      final double centerX = caret.dx;
      final double width = 30;
      final double height = lineHeight + 14;
      final double left = (centerX - width / 2).clamp(
        0,
        math.max(0, signature.maxWidth - width),
      );
      return _GapLayout(
        afterTokenIndex: entry.key,
        anchor: Offset(centerX.clamp(0, signature.maxWidth), top),
        hitRect: Rect.fromLTWH(left, top, width, height),
      );
    }).toList();

    return _MeasuredLayout(
      textSpan: textSpan,
      width: painter.width,
      height: math.max(painter.height, painter.preferredLineHeight),
      gaps: gaps,
    );
  }

  TextSpan _buildTextSpan(List<CommaToken> tokens, TextStyle textStyle) {
    final TextStyle commaStyle = textStyle.copyWith(
      color: AppColors.accent,
      fontWeight: FontWeight.w900,
      shadows: <Shadow>[
        Shadow(color: AppColors.accent.withValues(alpha: 0.95), blurRadius: 16),
        Shadow(color: AppColors.reward.withValues(alpha: 0.35), blurRadius: 24),
      ],
    );

    final List<InlineSpan> spans = <InlineSpan>[];
    for (int i = 0; i < tokens.length; i++) {
      final CommaToken token = tokens[i];
      spans.add(TextSpan(text: token.text));
      if (token.commaPlacedAfter) {
        spans.add(TextSpan(text: ',', style: commaStyle));
      }
      if (i < tokens.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }
    return TextSpan(style: textStyle, children: spans);
  }

  String _displayText(List<CommaToken> tokens) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < tokens.length; i++) {
      final CommaToken token = tokens[i];
      buffer.write(token.text);
      if (token.commaPlacedAfter) {
        buffer.write(',');
      }
      if (i < tokens.length - 1) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  Set<int> _placedIndexes(List<CommaToken> tokens) {
    return tokens
        .where((CommaToken token) => token.commaPlacedAfter)
        .map((CommaToken token) => token.index)
        .toSet();
  }

  Map<int, int> _gapTextOffsets(List<CommaToken> tokens) {
    final Map<int, int> offsets = <int, int>{};
    int textOffset = 0;
    for (int i = 0; i < tokens.length; i++) {
      final CommaToken token = tokens[i];
      textOffset += token.text.length;
      if (token.commaPlacedAfter) {
        textOffset += 1;
      }
      if (i < tokens.length - 1) {
        offsets[token.index] = textOffset;
        textOffset += 1;
      }
    }
    return offsets;
  }
}

class _LocalCorrectFeedback extends StatelessWidget {
  const _LocalCorrectFeedback({required this.gap, required this.pulseKey});

  final _GapLayout? gap;
  final int pulseKey;

  @override
  Widget build(BuildContext context) {
    if (gap == null) return const SizedBox.shrink();
    final Rect hitRect = gap!.hitRect;
    return Positioned(
      left: (hitRect.left - 10).clamp(0, double.infinity),
      top: math.max(0, hitRect.top - 36),
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey<int>(pulseKey),
          tween: Tween<double>(begin: 1, end: 0),
          duration: const Duration(milliseconds: 680),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, -12 * (1 - value)),
                child: Transform.scale(
                  scale: 0.90 + 0.24 * value,
                  child: child,
                ),
              ),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.52),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.38),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                '+100',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalWrongFeedback extends StatelessWidget {
  const _LocalWrongFeedback({required this.gap, required this.pulseKey});

  final _GapLayout? gap;
  final int pulseKey;

  @override
  Widget build(BuildContext context) {
    if (gap == null) return const SizedBox.shrink();
    final Rect hitRect = gap!.hitRect;
    return Positioned(
      left: (hitRect.left - 8).clamp(0, double.infinity),
      top: math.max(0, hitRect.bottom - 8),
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey<int>(pulseKey),
          tween: Tween<double>(begin: 1, end: 0),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: 0.92 + 0.22 * value, child: child),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.52),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.34),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Text(
                  'Not there',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: math.min(46, hitRect.width + 18),
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.75),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GapAffordance extends StatelessWidget {
  const _GapAffordance({required this.gap, required this.difficulty});

  final _GapLayout gap;
  final CommaDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final double opacity = switch (difficulty) {
      CommaDifficulty.beginner => 0.25,
      CommaDifficulty.medium => 0.17,
      CommaDifficulty.hard => 0.10,
    };
    final double size = switch (difficulty) {
      CommaDifficulty.beginner => 18,
      CommaDifficulty.medium => 15,
      CommaDifficulty.hard => 12,
    };
    final Rect hitRect = gap.hitRect;

    return Positioned(
      left: (hitRect.center.dx - size / 2).clamp(0, double.infinity),
      top: (hitRect.center.dy - size / 2).clamp(0, double.infinity),
      child: IgnorePointer(
        child: Container(
          key: const ValueKey<String>('comma-gap-affordance'),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: opacity * 0.20),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: opacity),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.accent.withValues(alpha: opacity * 0.75),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            ',',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accent.withValues(alpha: opacity + 0.10),
              fontWeight: FontWeight.w900,
              height: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _SentenceCompleteBurst extends StatelessWidget {
  const _SentenceCompleteBurst({required this.gaps});

  final List<_GapLayout> gaps;

  @override
  Widget build(BuildContext context) {
    if (gaps.isEmpty) return const SizedBox.shrink();
    final _GapLayout centerGap = gaps[gaps.length ~/ 2];

    return Positioned(
      left: math.max(0, centerGap.hitRect.center.dx - 18),
      top: math.max(0, centerGap.hitRect.top - 26),
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: const ValueKey<String>('sentence-complete-burst'),
          tween: Tween<double>(begin: 1, end: 0),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: 0.8 + (0.55 * value), child: child),
            );
          },
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.reward.withValues(alpha: 0.16),
              border: Border.all(
                color: AppColors.reward.withValues(alpha: 0.46),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.reward.withValues(alpha: 0.36),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Text(
              ',',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.reward,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeasuredLayout {
  const _MeasuredLayout({
    required this.textSpan,
    required this.width,
    required this.height,
    required this.gaps,
  });

  final TextSpan textSpan;
  final double width;
  final double height;
  final List<_GapLayout> gaps;

  _GapLayout? gapFor(int? afterTokenIndex) {
    if (afterTokenIndex == null) return null;
    for (final _GapLayout gap in gaps) {
      if (gap.afterTokenIndex == afterTokenIndex) return gap;
    }
    return null;
  }
}

class _GapLayout {
  const _GapLayout({
    required this.afterTokenIndex,
    required this.anchor,
    required this.hitRect,
  });

  final int afterTokenIndex;
  final Offset anchor;
  final Rect hitRect;
}

class _LayoutSignature {
  const _LayoutSignature({
    required this.text,
    required this.placedIndexes,
    required this.maxWidth,
    required this.textStyle,
    required this.textScaler,
    required this.direction,
  });

  final String text;
  final Set<int> placedIndexes;
  final double maxWidth;
  final TextStyle textStyle;
  final TextScaler textScaler;
  final TextDirection direction;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _LayoutSignature &&
        other.text == text &&
        setEquals(other.placedIndexes, placedIndexes) &&
        other.maxWidth == maxWidth &&
        other.textStyle == textStyle &&
        other.textScaler == textScaler &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(
    text,
    Object.hashAll(placedIndexes),
    maxWidth,
    textStyle,
    textScaler,
    direction,
  );
}
