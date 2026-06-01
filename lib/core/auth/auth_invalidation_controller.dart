import 'dart:async';

class AuthInvalidationController {
  AuthInvalidationController()
    : _controller = StreamController<void>.broadcast();

  final StreamController<void> _controller;

  Stream<void> get stream => _controller.stream;

  void notifyInvalidated() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }

  Future<void> close() => _controller.close();
}
