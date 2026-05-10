import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_prompt.dart';
import 'package:lexrush/features/games/commas/domain/services/comma_difficulty_service.dart';

class CommaRoundGenerator {
  CommaRoundGenerator({
    required List<CommaPrompt> prompts,
    CommaDifficultyService difficultyService = const CommaDifficultyService(),
  }) : _prompts = prompts,
       _difficultyService = difficultyService;

  final List<CommaPrompt> _prompts;
  final CommaDifficultyService _difficultyService;
  final Set<String> _usedPromptIds = <String>{};
  String? _lastPromptId;

  void reset() {
    _usedPromptIds.clear();
    _lastPromptId = null;
  }

  CommaPrompt nextPrompt({
    required int completedPrompts,
    required int timeLeft,
  }) {
    final CommaDifficulty target = _difficultyService.difficultyFor(
      completedPrompts: completedPrompts,
      timeLeft: timeLeft,
    );
    final List<CommaPrompt> candidates = _prompts
        .where((CommaPrompt prompt) => prompt.difficulty == target)
        .toList();
    final CommaPrompt prompt =
        _firstFresh(candidates) ?? _firstFresh(_prompts) ?? _prompts.first;
    _usedPromptIds.add(prompt.id);
    _lastPromptId = prompt.id;
    if (_usedPromptIds.length >= _prompts.length) {
      _usedPromptIds
        ..clear()
        ..add(prompt.id);
    }
    return prompt;
  }

  CommaPrompt? _firstFresh(List<CommaPrompt> prompts) {
    for (final CommaPrompt prompt in prompts) {
      if (prompt.id != _lastPromptId && !_usedPromptIds.contains(prompt.id)) {
        return prompt;
      }
    }
    for (final CommaPrompt prompt in prompts) {
      if (prompt.id != _lastPromptId) return prompt;
    }
    return null;
  }
}
