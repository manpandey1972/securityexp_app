import 'dart:async';

class EventBus {
  EventBus._();
  static final EventBus _instance = EventBus._();
  factory EventBus() => _instance;

  final StreamController<void> _profileUpdatedController =
      StreamController<void>.broadcast();

  /// Fires whenever the app transitions from background → foreground.
  /// Subscribers can use this to refresh stale lists/data.
  final StreamController<void> _appResumedController =
      StreamController<void>.broadcast();

  Stream<void> get onProfileUpdated => _profileUpdatedController.stream;
  Stream<void> get onAppResumed => _appResumedController.stream;

  void emitProfileUpdated() => _profileUpdatedController.add(null);
  void emitAppResumed() => _appResumedController.add(null);

  void dispose() {
    _profileUpdatedController.close();
    _appResumedController.close();
  }
}
