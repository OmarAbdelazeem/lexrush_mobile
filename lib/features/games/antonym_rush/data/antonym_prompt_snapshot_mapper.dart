import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_difficulty.dart';
import 'package:lexrush/features/games/antonym_rush/domain/entities/antonym_pair.dart';
import 'package:lexrush/shared/data/backend/create_game_session_dtos.dart';

abstract final class AntonymPromptSnapshotMapper {
  static List<AntonymPair> mapSessionPrompts(List<SessionPromptDto> snapshots) {
    final List<SessionPromptDto> ordered =
        List<SessionPromptDto>.from(snapshots)..sort(
          (SessionPromptDto a, SessionPromptDto b) =>
              a.orderIndex.compareTo(b.orderIndex),
        );

    return ordered
        .map(_mapPrompt)
        .whereType<AntonymPair>()
        .toList(growable: false);
  }

  static AntonymPair? _mapPrompt(SessionPromptDto snapshot) {
    final String targetWord = _stringValue(snapshot.contentJson['targetWord']);
    if (targetWord.isEmpty) return null;

    final Object? rawChoices = snapshot.contentJson['choices'];
    if (rawChoices is! List<dynamic> || rawChoices.length != 4) return null;

    final List<_BackendAntonymChoice> choices = rawChoices
        .whereType<Map<String, dynamic>>()
        .map(_choice)
        .whereType<_BackendAntonymChoice>()
        .toList(growable: false);
    if (choices.length != 4) return null;

    final String correctChoiceId = _stringValue(
      snapshot.answerJson['correctChoiceId'],
    );
    if (correctChoiceId.isEmpty) return null;

    final _BackendAntonymChoice? correctChoice = choices
        .where((_BackendAntonymChoice choice) => choice.id == correctChoiceId)
        .firstOrNull;
    if (correctChoice == null) return null;

    final List<AntonymPairOption> backendOptions = choices
        .map(
          (_BackendAntonymChoice choice) => AntonymPairOption(
            id: choice.id,
            word: choice.text,
            isCorrect: choice.id == correctChoiceId,
          ),
        )
        .toList(growable: false);
    final List<String> distractors = choices
        .where((_BackendAntonymChoice choice) => choice.id != correctChoiceId)
        .map((_BackendAntonymChoice choice) => choice.text)
        .toList(growable: false);

    return AntonymPair(
      word: targetWord,
      antonym: correctChoice.text,
      distractors: distractors,
      difficulty: _difficulty(snapshot),
      beginnerSafe: _difficulty(snapshot) == AntonymDifficulty.easy,
      backendOptions: backendOptions,
      explanation: _nullableStringValue(snapshot.explanation),
    );
  }

  static _BackendAntonymChoice? _choice(Map<String, dynamic> json) {
    final String id = _stringValue(json['id']);
    final String text = _stringValue(json['text']);
    if (id.isEmpty || text.isEmpty) return null;
    return _BackendAntonymChoice(id: id, text: text);
  }

  static AntonymDifficulty _difficulty(SessionPromptDto snapshot) {
    switch (snapshot.difficultyTag.toLowerCase()) {
      case 'beginner':
      case 'easy':
        return AntonymDifficulty.easy;
      case 'medium':
        return AntonymDifficulty.medium;
      case 'hard':
        return AntonymDifficulty.hard;
    }

    return switch (snapshot.difficulty) {
      <= 2 => AntonymDifficulty.easy,
      3 => AntonymDifficulty.medium,
      _ => AntonymDifficulty.hard,
    };
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

class _BackendAntonymChoice {
  const _BackendAntonymChoice({required this.id, required this.text});

  final String id;
  final String text;
}
