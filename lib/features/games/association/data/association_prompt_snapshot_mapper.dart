import 'package:lexrush/features/games/association/domain/entities/association_difficulty.dart';
import 'package:lexrush/features/games/association/domain/entities/association_prompt.dart';
import 'package:lexrush/features/games/association/domain/entities/association_type.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';

abstract final class AssociationPromptSnapshotMapper {
  static List<AssociationPrompt> mapSessionPrompts(
    List<SessionPromptDto> snapshots,
  ) {
    final List<SessionPromptDto> ordered =
        List<SessionPromptDto>.from(snapshots)..sort(
          (SessionPromptDto a, SessionPromptDto b) =>
              a.orderIndex.compareTo(b.orderIndex),
        );

    return ordered
        .map(_mapPrompt)
        .whereType<AssociationPrompt>()
        .toList(growable: false);
  }

  static AssociationPrompt? _mapPrompt(SessionPromptDto snapshot) {
    final String target = _stringValue(snapshot.contentJson['target']);
    final String explanation = _stringValue(snapshot.explanation);
    if (target.isEmpty || explanation.isEmpty) return null;

    final Object? rawChoices = snapshot.contentJson['choices'];
    if (rawChoices is! List<dynamic> || rawChoices.length != 2) return null;

    final List<_BackendAssociationChoice> choices = rawChoices
        .whereType<Map<String, dynamic>>()
        .map(_choice)
        .whereType<_BackendAssociationChoice>()
        .toList(growable: false);
    if (choices.length != 2) return null;

    final String correctChoiceId = _stringValue(
      snapshot.answerJson['correctChoiceId'],
    );
    if (correctChoiceId.isEmpty) return null;

    final _BackendAssociationChoice? correctChoice = choices
        .where(
          (_BackendAssociationChoice choice) => choice.id == correctChoiceId,
        )
        .firstOrNull;
    if (correctChoice == null) return null;

    final _BackendAssociationChoice wrongChoice = choices.firstWhere(
      (_BackendAssociationChoice choice) => choice.id != correctChoiceId,
    );

    return AssociationPrompt(
      targetWord: target,
      correctAnswer: correctChoice.text,
      wrongAnswer: wrongChoice.text,
      explanation: explanation,
      type: _type(snapshot.ruleType),
      difficulty: _difficulty(snapshot),
      beginnerSafe: _difficulty(snapshot) == AssociationDifficulty.easy,
      contextHint: _nullableStringValue(snapshot.contentJson['contextHint']),
      correctChoiceId: correctChoice.id,
      wrongChoiceId: wrongChoice.id,
    );
  }

  static _BackendAssociationChoice? _choice(Map<String, dynamic> json) {
    final String id = _stringValue(json['id']);
    final String text = _stringValue(json['text']);
    if (id.isEmpty || text.isEmpty) return null;
    return _BackendAssociationChoice(id: id, text: text);
  }

  static AssociationDifficulty _difficulty(SessionPromptDto snapshot) {
    switch (snapshot.difficultyTag.toLowerCase()) {
      case 'beginner':
      case 'easy':
        return AssociationDifficulty.easy;
      case 'medium':
        return AssociationDifficulty.medium;
      case 'hard':
        return AssociationDifficulty.hard;
    }

    return switch (snapshot.difficulty) {
      <= 1 => AssociationDifficulty.easy,
      2 => AssociationDifficulty.medium,
      _ => AssociationDifficulty.hard,
    };
  }

  static AssociationType _type(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AssociationType.meaningMatch;
    }
    for (final AssociationType type in AssociationType.values) {
      if (type.name == value) return type;
    }
    return AssociationType.meaningMatch;
  }

  static String? _nullableStringValue(Object? value) {
    final String string = _stringValue(value);
    return string.isEmpty ? null : string;
  }

  static String _stringValue(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }
}

class _BackendAssociationChoice {
  const _BackendAssociationChoice({required this.id, required this.text});

  final String id;
  final String text;
}
