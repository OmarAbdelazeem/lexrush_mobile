abstract class AudioFeedbackPort {
  Future<void> playSuccess();
  Future<void> playError();
  Future<void> playMissed();
}
