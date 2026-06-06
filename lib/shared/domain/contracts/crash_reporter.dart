abstract class CrashReporter {
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? context,
  });

  void setUserId(String? userId);
}
