import 'dart:async';

class EventBus {
  EventBus._();
  static final EventBus _instance = EventBus._();
  factory EventBus() => _instance;

  final StreamController<void> _profileUpdatedController =
      StreamController<void>.broadcast();

  Stream<void> get onProfileUpdated => _profileUpdatedController.stream;

  void emitProfileUpdated() => _profileUpdatedController.add(null);

  void dispose() {
    _profileUpdatedController.close();
  }
}
