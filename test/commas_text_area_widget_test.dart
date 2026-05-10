import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    final RichText text = tester.widget<RichText>(find.byType(RichText).first);
    expect(text.text.toPlainText(), contains('Agra, India.'));
    expect(text.text.toPlainText(), isNot(contains('Agra , India.')));
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
}

class _Harness extends StatelessWidget {
  const _Harness({required this.tokens, this.onGapTap});

  final List<CommaToken> tokens;
  final ValueChanged<int>? onGapTap;

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
