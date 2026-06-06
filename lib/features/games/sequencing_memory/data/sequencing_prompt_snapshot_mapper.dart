import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_difficulty.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_prompt.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';

abstract final class SequencingPromptSnapshotMapper {
  static List<SequencingPrompt> mapSessionPrompts(
    List<SessionPromptDto> snapshots,
  ) {
    final List<SessionPromptDto> ordered =
        List<SessionPromptDto>.from(snapshots)..sort(
          (SessionPromptDto a, SessionPromptDto b) =>
              a.orderIndex.compareTo(b.orderIndex),
        );

    return ordered
        .map(_mapPrompt)
        .whereType<SequencingPrompt>()
        .toList(growable: false);
  }

  static SequencingPrompt? _mapPrompt(SessionPromptDto snapshot) {
    final List<String>? partOne = _stringList(snapshot.contentJson['partOne']);
    final List<String>? partTwo = _stringList(snapshot.contentJson['partTwo']);
    final List<String>? combined = _stringList(snapshot.contentJson['combined']);

    if (partOne == null || partOne.isEmpty) return null;
    if (partTwo == null || partTwo.isEmpty) return null;
    if (combined == null || combined.isEmpty) return null;

    // partOne and partTwo must be equal-length halves (generator splits with ~/ 2)
    if (partOne.length != partTwo.length) return null;

    // combined must equal [...partOne, ...partTwo]
    final List<String> expectedCombined = <String>[...partOne, ...partTwo];
    if (!_listEquals(combined, expectedCombined)) return null;

    // Parse optional items[]
    List<SequencingBackendItem>? backendItems;
    final Object? rawItems = snapshot.contentJson['items'];
    if (rawItems != null) {
      if (rawItems is! List<dynamic>) return null;
      final List<SequencingBackendItem> parsed = <SequencingBackendItem>[];
      for (final Object? entry in rawItems) {
        if (entry is! Map<String, dynamic>) return null;
        final String id = _stringValue(entry['id']);
        final String text = _stringValue(entry['text']);
        if (id.isEmpty || text.isEmpty) return null;
        parsed.add(SequencingBackendItem(id: id, text: text));
      }
      // items texts must match combined
      final List<String> itemTexts = parsed
          .map((SequencingBackendItem i) => i.text)
          .toList(growable: false);
      if (!_listEquals(itemTexts, combined)) return null;
      backendItems = parsed;
    }

    // Parse optional correctOrder[]
    List<String>? correctOrderIds;
    final Object? rawCorrectOrder = snapshot.answerJson['correctOrder'];
    if (rawCorrectOrder != null) {
      if (rawCorrectOrder is! List<dynamic>) return null;
      final List<String> ids = rawCorrectOrder
          .whereType<String>()
          .toList(growable: false);
      if (ids.length != rawCorrectOrder.length) return null;

      // All IDs must exist in backendItems
      if (backendItems == null) return null;
      final Map<String, String> idToText = <String, String>{
        for (final SequencingBackendItem item in backendItems)
          item.id: item.text,
      };
      for (final String id in ids) {
        if (!idToText.containsKey(id)) return null;
      }

      // Resolving correctOrder IDs through items must equal combined
      final List<String> resolved = ids
          .map((String id) => idToText[id]!)
          .toList(growable: false);
      if (!_listEquals(resolved, combined)) return null;

      correctOrderIds = ids;
    }

    final SequencingDifficulty difficulty = _difficulty(snapshot);

    return SequencingPrompt(
      id: snapshot.promptId,
      items: combined,
      theme: _theme(snapshot.contentJson['theme']),
      difficulty: difficulty,
      beginnerSafe: snapshot.difficultyTag.toLowerCase() == 'beginner',
      memoryHint: _nullableStringValue(snapshot.contentJson['memoryHint']),
      explanation: _nullableStringValue(snapshot.explanation),
      backendItems: backendItems,
      correctOrderIds: correctOrderIds,
    );
  }

  static SequencingDifficulty _difficulty(SessionPromptDto snapshot) {
    switch (snapshot.difficultyTag.toLowerCase()) {
      case 'beginner':
        return SequencingDifficulty.beginner;
      case 'medium':
        return SequencingDifficulty.medium;
      case 'hard':
        return SequencingDifficulty.hard;
    }
    return switch (snapshot.difficulty) {
      <= 1 => SequencingDifficulty.beginner,
      2 => SequencingDifficulty.medium,
      _ => SequencingDifficulty.hard,
    };
  }

  static SequencingTheme _theme(Object? value) {
    if (value is! String) return SequencingTheme.route;
    switch (value.toLowerCase()) {
      case 'daily_routine':
      case 'cooking_steps':
      case 'emergency_procedure':
        return SequencingTheme.errands;
      case 'city_directions':
      case 'nature_trail':
      case 'morning_commute':
      default:
        return SequencingTheme.route;
    }
  }

  static List<String>? _stringList(Object? value) {
    if (value is! List<dynamic>) return null;
    final List<String> result = value.whereType<String>().toList(growable: false);
    if (result.length != value.length) return null;
    return result;
  }

  static String? _nullableStringValue(Object? value) {
    final String s = _stringValue(value);
    return s.isEmpty ? null : s;
  }

  static String _stringValue(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
