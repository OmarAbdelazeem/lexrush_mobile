import 'dart:math' as math;

import 'package:lexrush/features/games/association/domain/entities/association_game_result.dart';
import 'package:lexrush/features/games/commas/domain/entities/commas_game_result.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_game_result.dart';
import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:lexrush/shared/domain/entities/game_result.dart';
import 'package:lexrush/shared/domain/entities/game_session_stats.dart';

abstract final class BackendGameIds {
  static const String antonymRush = 'antonym_rush';
  static const String association = 'association';
  static const String sequencingMemory = 'sequencing_memory';
  static const String commas = 'commas';
}

abstract final class BackendResultMappers {
  static SubmitGameResultRequest antonymRush(GameResult result) {
    final GameSessionStats stats = result.stats;
    return _fromStats(
      stats,
      wrongAnswers: _derivedWrongAnswers(stats),
      missedAnswers: stats.missedWords,
    );
  }

  static SubmitGameResultRequest association(AssociationGameResult result) {
    final GameSessionStats stats = result.summary.stats;
    return _fromStats(
      stats,
      wrongAnswers: _derivedWrongAnswers(stats),
      missedAnswers: stats.missedWords,
    );
  }

  static SubmitGameResultRequest sequencingMemory(SequencingGameResult result) {
    final GameSessionStats stats = result.summary.stats;
    return _fromStats(
      stats,
      wrongAnswers: stats.missedWords,
      missedAnswers: 0,
      wordsSolved: result.sequencesCompleted,
    );
  }

  static SubmitGameResultRequest commas(CommasGameResult result) {
    final GameSessionStats stats = result.summary.stats;
    return _fromStats(stats, wrongAnswers: stats.missedWords, missedAnswers: 0);
  }

  static SubmitGameResultRequest _fromStats(
    GameSessionStats stats, {
    required int wrongAnswers,
    required int missedAnswers,
    int? wordsSolved,
  }) {
    return SubmitGameResultRequest(
      score: stats.score,
      accuracy: stats.accuracy / 100,
      totalAttempts: stats.totalAttempts,
      correctAnswers: stats.correctAnswers,
      wrongAnswers: math.max(0, wrongAnswers),
      missedAnswers: math.max(0, missedAnswers),
      wordsSolved: wordsSolved ?? stats.wordsSolved,
      bestCombo: stats.bestCombo,
      averageResponseTimeMs: stats.averageResponseTimeMs,
    );
  }

  static int _derivedWrongAnswers(GameSessionStats stats) {
    return stats.totalAttempts - stats.correctAnswers - stats.missedWords;
  }
}
