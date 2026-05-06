enum SequencingStage {
  initial,
  listenPartOne,
  arrangePartOne,
  feedbackPartOne,
  listenPartTwo,
  arrangePartTwo,
  feedbackPartTwo,
  arrangeCombined,
  feedbackCombined,
  paused,
  finished,
}

extension SequencingStageX on SequencingStage {
  bool get isListening {
    return switch (this) {
      SequencingStage.listenPartOne || SequencingStage.listenPartTwo => true,
      _ => false,
    };
  }

  bool get isArranging {
    return switch (this) {
      SequencingStage.arrangePartOne ||
      SequencingStage.arrangePartTwo ||
      SequencingStage.arrangeCombined => true,
      _ => false,
    };
  }

  bool get isFeedback {
    return switch (this) {
      SequencingStage.feedbackPartOne ||
      SequencingStage.feedbackPartTwo ||
      SequencingStage.feedbackCombined => true,
      _ => false,
    };
  }

  bool get isCombined {
    return switch (this) {
      SequencingStage.arrangeCombined ||
      SequencingStage.feedbackCombined => true,
      _ => false,
    };
  }
}
