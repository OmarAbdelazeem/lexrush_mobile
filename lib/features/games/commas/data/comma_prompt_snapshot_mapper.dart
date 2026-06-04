import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_insertion_point.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_prompt.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_rule_type.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';

abstract final class CommaPromptSnapshotMapper {
  static List<CommaPrompt> mapSessionPrompts(List<SessionPromptDto> snapshots) {
    final List<SessionPromptDto> ordered =
        List<SessionPromptDto>.from(snapshots)..sort(
          (SessionPromptDto a, SessionPromptDto b) =>
              a.orderIndex.compareTo(b.orderIndex),
        );

    return ordered
        .map(_mapPrompt)
        .whereType<CommaPrompt>()
        .toList(growable: false);
  }

  static CommaPrompt? _mapPrompt(SessionPromptDto snapshot) {
    final String displayText = _stringValue(
      snapshot.contentJson['displayTextWithoutCommas'],
    );
    if (displayText.isEmpty) return null;

    final List<String> tokens = displayText.split(' ');
    if (tokens.length < 2) return null;

    final List<int> indexes = _insertionIndexes(snapshot.answerJson);
    if (indexes.isEmpty) return null;
    if (indexes.any((int index) => index < 0 || index >= tokens.length - 1)) {
      return null;
    }

    final String backendCorrectText = _stringValue(
      snapshot.contentJson['correctTextWithCommas'],
    );
    final List<int> sortedIndexes = List<int>.from(indexes)..sort();

    return CommaPrompt(
      id: snapshot.promptId,
      displayTextWithoutCommas: displayText,
      correctTextWithCommas: backendCorrectText.isNotEmpty
          ? backendCorrectText
          : _deriveCorrectText(tokens, sortedIndexes),
      insertionPoints: sortedIndexes
          .map(
            (int index) => CommaInsertionPoint(
              afterTokenIndex: index,
              beforeToken: tokens[index],
              afterToken: tokens[index + 1],
            ),
          )
          .toList(growable: false),
      ruleType: _ruleType(snapshot.ruleType),
      difficulty: _difficulty(snapshot),
      beginnerSafe: _difficulty(snapshot) == CommaDifficulty.beginner,
      explanation: _stringValue(snapshot.explanation),
    );
  }

  static List<int> _insertionIndexes(Map<String, dynamic> answerJson) {
    final Object? rawPoints = answerJson['insertionPoints'];
    if (rawPoints is! List<dynamic>) return <int>[];

    final Set<int> indexes = <int>{};
    for (final Object? point in rawPoints) {
      if (point is int) {
        indexes.add(point);
      } else if (point is Map<String, dynamic>) {
        final Object? rawIndex = point['afterTokenIndex'];
        if (rawIndex is int) indexes.add(rawIndex);
      }
    }
    return indexes.toList(growable: false);
  }

  static String _deriveCorrectText(List<String> tokens, List<int> indexes) {
    final Set<int> indexSet = indexes.toSet();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < tokens.length; i++) {
      buffer.write(tokens[i]);
      if (indexSet.contains(i)) buffer.write(',');
      if (i < tokens.length - 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  static CommaDifficulty _difficulty(SessionPromptDto snapshot) {
    switch (snapshot.difficultyTag.toLowerCase()) {
      case 'beginner':
      case 'easy':
        return CommaDifficulty.beginner;
      case 'medium':
        return CommaDifficulty.medium;
      case 'hard':
        return CommaDifficulty.hard;
    }

    return switch (snapshot.difficulty) {
      <= 1 => CommaDifficulty.beginner,
      2 => CommaDifficulty.medium,
      _ => CommaDifficulty.hard,
    };
  }

  static CommaRuleType _ruleType(String? value) {
    if (value == null || value.trim().isEmpty) return CommaRuleType.general;
    for (final CommaRuleType ruleType in CommaRuleType.values) {
      if (ruleType.name == value) return ruleType;
    }
    return CommaRuleType.general;
  }

  static String _stringValue(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }
}
