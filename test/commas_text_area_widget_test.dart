import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';
import 'package:lexrush/features/games/commas/presentation/widgets/comma_gap_detector.dart';
import 'package:lexrush/features/games/commas/presentation/widgets/comma_text_area.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_token.dart';

void main() {
  testWidgets('renders placed comma as attached prose', (tester) async {
    await tester.pumpWidget(
      _Harness(
        tokens: _tokens(
          <String>[
            'The',
            'Taj',
            'Mahal',
            'is',
            'located',
            'in',
            'Agra',
            'India.',
          ],
          placedAfter: <int>{6},
        ),
      ),
    );

    final List<String> renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((RichText text) => text.text.toPlainText())
        .toList();
    expect(renderedText, contains(contains('Agra, India.')));
    expect(renderedText, isNot(contains(contains('Agra , India.'))));
  });

  testWidgets('gap overlay forwards afterTokenIndex', (tester) async {
    int? tappedGap;
    await tester.pumpWidget(
      _Harness(
        tokens: _tokens(<String>[
          'The',
          'Taj',
          'Mahal',
          'is',
          'located',
          'in',
          'Agra',
          'India.',
        ]),
        onGapTap: (index) => tappedGap = index,
      ),
    );

    await tester.tap(find.byType(CommaGapDetector).at(6));

    expect(tappedGap, 6);
  });

  testWidgets('debug hitboxes are disabled by default', (tester) async {
    await tester.pumpWidget(
      _Harness(tokens: _tokens(<String>['After', 'dinner', 'we', 'walked.'])),
    );

    final Container debugContainer = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(CommaGapDetector).first,
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = debugContainer.decoration! as BoxDecoration;

    expect(decoration.border!.top.color, Colors.transparent);
  });

  testWidgets('ghost affordances render for every tappable gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        difficulty: CommaDifficulty.beginner,
        tokens: _tokens(<String>['After', 'dinner', 'we', 'walked.']),
      ),
    );

    expect(find.byType(CommaGapDetector), findsNWidgets(3));
    expect(
      find.byKey(const ValueKey<String>('comma-gap-affordance')),
      findsNWidgets(3),
    );
  });
}

class _Harness extends StatelessWidget {
  const _Harness({
    required this.tokens,
    this.onGapTap,
    this.difficulty = CommaDifficulty.medium,
  });

  final List<CommaToken> tokens;
  final ValueChanged<int>? onGapTap;
  final CommaDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 280,
            child: CommaTextArea(
              tokens: tokens,
              flashGapAfterTokenIndex: null,
              sentenceCompletePulse: false,
              difficulty: difficulty,
              onGapTap: onGapTap ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }
}

List<CommaToken> _tokens(
  List<String> words, {
  Set<int> placedAfter = const {},
}) {
  return words.asMap().entries.map((entry) {
    return CommaToken(
      text: entry.value,
      index: entry.key,
      commaRequiredAfter: false,
      commaPlacedAfter: placedAfter.contains(entry.key),
    );
  }).toList();
}
