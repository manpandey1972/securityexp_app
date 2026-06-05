import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

import '../platform_utils.dart';
import 'callkit_service.dart' show CallKitAction;

/// Android equivalent of the iOS [CallKitService].
///
/// Uses `flutter_callkit_incoming` to render a full-screen native incoming-call
/// UI (ringing screen with Accept/Decline buttons) on Android — including when
/// the device is locked or the app has been killed.
///
/// Shape parity with [CallKitService]:
///   * exposes `Stream<CallKitAction> callActions` so [IncomingCallStrategy]
///     can listen to native answer/decline events with a unified API.
///   * provides `showIncomingCall(...)` / `endCall(...)` / `endAllCalls()`
///     methods that mirror the iOS surface.
///
/// This service is a no-op on non-Android platforms.
class AndroidCallKitService {
  static const _tag = 'AndroidCallKit';

  /// Method channel exposed by [MainActivity] for tearing down CallKit state
  /// owned by the native FCM service ([GoAegentMessagingService]).
  ///
  /// Specifically: when an `incoming_call` push arrives while the app is
  /// killed, our native service creates its own `CallkitSoundPlayerManager`
  /// to ring the device. The plugin's own accept/decline teardown can't stop
  /// that instance (different object, and the plugin uses an explicit
  /// broadcast targeting its own receiver class — so a manifest receiver of
  /// ours can never intercept the action). This channel is the bridge that
  /// lets Dart explicitly ask native to stop the ringer and cancel the
  /// notification once any terminal event fires.
  static const MethodChannel _callKitChannel =
      MethodChannel('com.goaegent.securityexperts.call/callkit');

  static AndroidCallKitService? _instance;

  AndroidCallKitService._internal();

  factory AndroidCallKitService() {
    _instance ??= AndroidCallKitService._internal();
    return _instance!;
  }

  final StreamController<CallKitAction> _callActionController =
      StreamController<CallKitAction>.broadcast();

  StreamSubscription? _eventSubscription;
  bool _isInitialized = false;

  /// Active call UUID, if any.
  String? _activeCallUUID;

  /// Most recent call data we showed CallKit UI for. Used to enrich
  /// [CallKitAction.data] when the native event arrives without payload.
  Map<String, dynamic>? _activeCallData;

  /// Call IDs for which we have already emitted an `answerCall` action.
  /// Prevents a duplicate accept (which would surface as a benign-but-noisy
  /// "Failed to connect to call server" snackbar) when both:
  ///   * the cold-start [_processColdStartActiveCalls] synthesis, and
  ///   * a queued native [Event.actionCallAccept]
  /// fire for the same call.
  final Set<String> _answeredCallIds = <String>{};

  /// Call IDs we proactively ended because they were stale plugin entries
  /// (no matching Firestore `incoming_calls` doc). The native plugin will
  /// echo an `actionCallEnded` event for these — we must NOT forward those
  /// to the higher-level listener, otherwise an active, unrelated call
  /// would be torn down by [IncomingCallStrategy._handleCallKitEnd].
  final Set<String> _purgedStaleCallIds = <String>{};

  /// Whether this platform supports the Android CallKit flow.
  bool get isAvailable => PlatformUtils.isAndroid;

  /// Stream of native call actions (mirrors [CallKitService.callActions]).
  Stream<CallKitAction> get callActions => _callActionController.stream;

  /// Currently-active call UUID (matches what was passed to `showIncomingCall`).
  String? get activeCallUUID => _activeCallUUID;

  /// Synchronously-ish peek at the call IDs the plugin currently considers
  /// "active" (was answered via the native UI but not yet ended).
  ///
  /// Used by [IncomingCallStrategy] at startup to pre-track these IDs and
  /// suppress the in-app incoming-call banner that the Firestore listener
  /// would otherwise show while [_processColdStartActiveCalls] is still
  /// waiting for Firebase Auth to restore.
  ///
  /// Returns the plugin's primary `id` field for each active call PLUS any
  /// `call_id` / `room_id` keys nested in the call's `extra` map. The
  /// plugin only stores one identifier per call, but the rest of the app
  /// may key calls by either of those values (the Firestore listener
  /// surfaces `session.callId`, which can differ from `session.roomId`).
  /// Returning every known alias lets the caller suppress the Flutter
  /// banner regardless of which id the upstream uses.
  ///
  /// Returns an empty list on non-Android platforms or on plugin error.
  Future<List<String>> peekActiveCallIds() async {
    if (!isAvailable) return const [];
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is! List) return const [];
      final ids = <String>{};
      for (final raw in calls) {
        if (raw is! Map) continue;
        final id = raw['id'] as String?;
        if (id != null && id.isNotEmpty) ids.add(id);
        final extra = raw['extra'];
        if (extra is Map) {
          final callId = extra['call_id'] as String?;
          if (callId != null && callId.isNotEmpty) ids.add(callId);
          final roomId = extra['room_id'] as String?;
          if (roomId != null && roomId.isNotEmpty) ids.add(roomId);
        }
      }
      return ids.toList(growable: false);
    } catch (e) {
      sl<AppLogger>().warning('peekActiveCallIds failed: $e', tag: _tag);
      return const [];
    }
  }

  /// Initialize listener for CallKit events.
  /// Safe to call multiple times.
  Future<void> initialize() async {
    if (_isInitialized || !isAvailable) return;
    _isInitialized = true;

    sl<AppLogger>().debug('Initializing event listener', tag: _tag);

    _eventSubscription = FlutterCallkitIncoming.onEvent.listen(_handleEvent);

    // Cold-start handling: if the app was launched by the user tapping Accept
    // on the native CallKit UI, the corresponding `actionCallAccept` event may
    // already have been dispatched before this listener attached and would be
    // lost. Query the plugin for any currently-active (already-accepted) calls
    // and synthesize the answer action so the rest of the pipeline runs.
    //
    // Run in the background — we must not block app startup for up to 8s while
    // waiting for Firebase Auth to restore.
    unawaited(_processColdStartActiveCalls());

    // Note: cold-start decline handling is now done natively by
    // [GoAegentApplication] + [RejectCallWorker] — see their kdocs.
    // Dart no longer drains a pending-decline queue.
  }

  /// Look up active calls left over from a CallKit accept on cold-start and
  /// emit a synthetic `answerCall` action so [IncomingCallStrategy] picks it up.
  ///
  /// We must:
  ///   1. Wait for Firebase Auth to restore (otherwise `acceptCall` Cloud
  ///      Function call runs unauthenticated).
  ///   2. **Verify the call still exists in Firestore** before synthesizing
  ///      an accept. The plugin's `activeCalls()` includes stale entries from
  ///      prior sessions — accepting them would fire dozens of `acceptCall`
  ///      RPCs that all return 404 / "Call already handled" and surface as a
  ///      "Failed to connect to call server" snackbar to the user.
  Future<void> _processColdStartActiveCalls() async {
    final coldStartSw = Stopwatch()..start();
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is! List || calls.isEmpty) return;

      sl<AppLogger>().debug(
        'Cold-start active calls: ${calls.length}',
        tag: _tag,
      );

      // Ask the host Activity whether the process was started via a
      // flutter_callkit_incoming launch intent (Accept/Decline tap on the
      // native UI). If not, the current process start is a normal app
      // launch — any `isAccepted=true` entry in `ACTIVE_CALLS` is stale
      // leftover from a prior session and must NOT be auto-answered.
      // (Otherwise the user lands on a "joining call" screen after the
      // splash on every normal launch.)
      final launchSw = Stopwatch()..start();
      final bool launchedFromCallKit = await _wasLaunchedFromCallKit();
      launchSw.stop();
      sl<AppLogger>().info(
        '[ColdStartTiming] wasLaunchedFromCallKit=$launchedFromCallKit took ${launchSw.elapsedMilliseconds}ms',
        tag: _tag,
      );

      if (!launchedFromCallKit) {
        // Normal app launch with stale ACTIVE_CALLS entries — purge them
        // outright. We can't reliably tell genuine "ringing" entries from
        // stale ones without round-tripping every id through Firestore,
        // but on a normal launch the live FCM/Firestore listener path
        // will re-deliver any genuinely-pending call, so purging is safe.
        sl<AppLogger>().info(
          'Cold-start: ${calls.length} stale CallKit entries from prior '
          'session (normal app launch) — purging.',
          tag: _tag,
        );
        for (final raw in calls) {
          if (raw is! Map) continue;
          final id = raw['id'];
          if (id is String && id.isNotEmpty) {
            _purgedStaleCallIds.add(id);
          }
        }
        try {
          await FlutterCallkitIncoming.endAllCalls();
        } catch (e) {
          sl<AppLogger>().warning(
            'Cold-start endAllCalls failed: $e',
            tag: _tag,
          );
        }
        return;
      }

      // Wait for Firebase Auth restoration before triggering acceptCall.
      // Returns immediately if a user is already signed in.
      final authSw = Stopwatch()..start();
      final user = await _awaitAuthReady();
      authSw.stop();
      sl<AppLogger>().info(
        '[ColdStartTiming] awaitAuthReady took ${authSw.elapsedMilliseconds}ms (user=${user?.uid ?? 'null'})',
        tag: _tag,
      );
      if (user == null) {
        sl<AppLogger>().warning(
          'No authenticated user on cold-start; cannot accept CallKit call. '
          'Ending native UI to avoid stuck state.',
          tag: _tag,
        );
        // Dismiss the native UI for any active call we can’t honour.
        await endAllCalls();
        return;
      }

      final firestore = FirestoreInstance().db;
      final incomingCallsRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('incoming_calls');

      // Collect ids that exist but show `isAccepted=false` so we can retry
      // resolving them. This handles the race between the plugin's
      // `ACTION_CALL_ACCEPT` broadcast (which persists `isAccepted=true` via
      // `addCall`) and our MainActivity startup. The broadcast and the
      // activity launch are posted on the same handler thread by
      // `TransparentActivity.onCreate`, so MainActivity *can* start before
      // the broadcast receiver finishes saving — in which case the first
      // `activeCalls()` read sees the old `isAccepted=false` state and we
      // would otherwise skip the synthesis, leaving the user staring at a
      // blank screen while the caller is still ringing.
      final List<String> pendingAcceptRecheck = [];

      Future<void> resolveCall(Map<String, dynamic> m) async {
        final id = m['id'] as String?;
        if (id == null || id.isEmpty) return;

        final extra = m['extra'];
        final extraMap = extra is Map
            ? Map<String, dynamic>.from(extra)
            : <String, dynamic>{};

        final bool isAccepted = (m['isAccepted'] as bool?) ?? false;

        if (isAccepted) {
          // isAccepted == true: user tapped Accept on the native UI.
          // Always synthesize the answer so the app navigates to the call
          // page. No Firestore validation needed — the user's tap is the
          // ground truth.
          _activeCallUUID = id;
          _activeCallData = extraMap;

          if (!_answeredCallIds.add(id)) {
            sl<AppLogger>().debug(
              'Cold-start: already answered $id, skipping synthesis',
              tag: _tag,
            );
            return;
          }

          sl<AppLogger>().info(
            'Synthesizing answerCall for cold-start call $id',
            tag: _tag,
          );
          // The native plugin may not have stopped its ringer on the
          // cold-start accept (its singleton was null when the broadcast
          // fired). Force-stop ours now that we're handling the answer.
          // Belt-and-braces with the [GoAegentApplication] lifecycle
          // callback — both are idempotent.
          _stopNativeCallKit(id);
          _emit(id, 'answerCall', extraMap);
          return;
        }

        // isAccepted == false here. Two possibilities:
        //   (a) The user accepted on the lock-screen UI but the broadcast
        //       receiver hasn't yet flipped `isAccepted=true` in the
        //       plugin's SharedPreferences. We need to retry.
        //   (b) The entry is a stale ringing leftover from a prior session
        //       (the FCM/Firestore call doc may or may not still exist).
        //
        // We can't distinguish (a) from (b) just from the snapshot. Defer
        // a decision: queue the id for a brief retry. If `isAccepted`
        // flips to true within the retry window, we handle case (a);
        // otherwise we fall through to the stale-call check.
        pendingAcceptRecheck.add(id);
      }

      for (final raw in calls) {
        if (raw is! Map) continue;
        await resolveCall(Map<String, dynamic>.from(raw));
      }

      // Retry loop for entries that were `isAccepted=false` on first read.
      // Total wait budget: ~1.5s (5 × 300ms). This is well within the
      // typical broadcast→addCall delay (a few hundred ms at most) but
      // small enough that the user doesn't perceive a stall.
      const retryDelay = Duration(milliseconds: 300);
      const maxRetries = 5;
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        if (pendingAcceptRecheck.isEmpty) break;
        await Future.delayed(retryDelay);

        final List<Map<String, dynamic>> refreshed;
        try {
          final rawList = await FlutterCallkitIncoming.activeCalls();
          if (rawList is! List) {
            sl<AppLogger>().debug(
              'Cold-start retry $attempt: activeCalls returned ${rawList.runtimeType}',
              tag: _tag,
            );
            continue;
          }
          refreshed = rawList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } catch (e) {
          sl<AppLogger>().warning(
            'Cold-start retry $attempt: activeCalls failed: $e',
            tag: _tag,
          );
          continue;
        }

        // Build a lookup of refreshed state for the ids still pending.
        final stillPending = <String>[];
        for (final id in pendingAcceptRecheck) {
          final match = refreshed.firstWhere(
            (m) => m['id'] == id,
            orElse: () => const <String, dynamic>{},
          );
          if (match.isEmpty) {
            // Entry vanished entirely (e.g. timeout fired). Drop from
            // recheck list; nothing more to do.
            sl<AppLogger>().debug(
              'Cold-start retry $attempt: entry $id no longer present',
              tag: _tag,
            );
            continue;
          }
          final isAcceptedNow = (match['isAccepted'] as bool?) ?? false;
          if (isAcceptedNow) {
            sl<AppLogger>().info(
              'Cold-start retry $attempt: $id now isAccepted=true — '
              'synthesizing answer',
              tag: _tag,
            );
            await resolveCall(match);
          } else {
            stillPending.add(id);
          }
        }
        pendingAcceptRecheck
          ..clear()
          ..addAll(stillPending);
      }

      // Any ids still pending after the retry window are treated as
      // ringing leftovers from a prior session, not accepted calls. Check
      // Firestore (server-side) and purge any that are confirmed missing.
      // Anything that the server confirms still exists is left alone for
      // the live Firestore listener / FCM path to handle.
      for (final id in pendingAcceptRecheck) {
        bool confirmedMissing = false;
        try {
          final snap = await incomingCallsRef
              .doc(id)
              .get(const GetOptions(source: Source.server));
          confirmedMissing = !snap.exists;
        } catch (e) {
          sl<AppLogger>().warning(
            'Cold-start: Firestore server check failed for $id: $e — '
            'leaving entry as-is (will not purge).',
            tag: _tag,
          );
        }

        if (confirmedMissing) {
          sl<AppLogger>().info(
            'Cold-start: stale ringing CallKit entry $id (server confirms '
            'no incoming_calls doc) — purging native UI.',
            tag: _tag,
          );
          _purgedStaleCallIds.add(id);
          try {
            await FlutterCallkitIncoming.endCall(id);
          } catch (_) {}
        } else {
          sl<AppLogger>().debug(
            'Cold-start: ringing CallKit entry $id present but not accepted '
            '— leaving native UI to handle.',
            tag: _tag,
          );
        }
      }
    } catch (e) {
      sl<AppLogger>().warning(
        'Failed to read activeCalls on cold-start: $e',
        tag: _tag,
      );
    } finally {
      coldStartSw.stop();
      sl<AppLogger>().info(
        '[ColdStartTiming] _processColdStartActiveCalls total ${coldStartSw.elapsedMilliseconds}ms',
        tag: _tag,
      );
    }
  }

  /// Returns the current Firebase user if already signed in, otherwise waits
  /// (up to 8s) for [FirebaseAuth.authStateChanges] to emit a non-null user.
  Future<User?> _awaitAuthReady() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser;

    try {
      return await auth
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return auth.currentUser; // may still be null
    }
  }

  /// Native method channel handle into [MainActivity]. Returns true if the
  /// current process was started via a `flutter_callkit_incoming` accept/
  /// decline intent (user tapped a button on the lock-screen UI), false
  /// for normal launches (icon tap, deep link, etc.). Defaults to false on
  /// any failure so we err on the side of NOT auto-routing into a call
  /// screen on cold start.
  static const MethodChannel _launchIntentChannel =
      MethodChannel('com.goaegent.securityexperts.call/launchIntent');

  Future<bool> _wasLaunchedFromCallKit() async {
    try {
      final result =
          await _launchIntentChannel.invokeMethod<bool>('wasLaunchedFromCallKit');
      return result == true;
    } catch (e) {
      sl<AppLogger>().debug(
        'wasLaunchedFromCallKit channel call failed: $e — assuming false',
        tag: _tag,
      );
      return false;
    }
  }

  void _handleEvent(CallEvent? event) {
    if (event == null) return;

    final body = event.body is Map ? Map<String, dynamic>.from(event.body) : <String, dynamic>{};
    final id = body['id'] as String? ?? _activeCallUUID ?? '';
    final extra = body['extra'];
    final extraMap = extra is Map ? Map<String, dynamic>.from(extra) : null;

    sl<AppLogger>().debug(
      'Event: ${event.event} for $id',
      tag: _tag,
    );

    switch (event.event) {
      case Event.actionCallAccept:
        // User tapped "Accept" on the native incoming call UI.
        _activeCallUUID = id;
        // Stop the native FCM-service-owned ringtone and dismiss the
        // incoming notification. See [_callKitChannel] kdoc for why this
        // can't be done by the plugin alone.
        _stopNativeCallKit(id);
        if (id.isNotEmpty && !_answeredCallIds.add(id)) {
          sl<AppLogger>().debug(
            'Ignoring duplicate actionCallAccept for $id',
            tag: _tag,
          );
          break;
        }
        // Gate the answer emission on Firebase Auth. On cold-start the
        // plugin can deliver this event before auth has restored — emitting
        // immediately would call `acceptCall` Cloud Function unauthenticated
        // and the request would fail. By awaiting auth here we ensure the
        // downstream `acceptCall` RPC is authorized.
        unawaited(_emitAnswerWhenAuthReady(id, _mergedData(extraMap)));
        break;

      case Event.actionCallDecline:
        // User tapped "Decline" on the native incoming call UI.
        _stopNativeCallKit(id);
        _emit(id, 'endCall', {
          'reason': 'declined',
          ...?_mergedData(extraMap),
        });
        if (_activeCallUUID == id) _activeCallUUID = null;
        _answeredCallIds.remove(id);
        break;

      case Event.actionCallEnded:
      case Event.actionCallTimeout:
        // Either the user hung up an active call, or the ring timed out.
        _stopNativeCallKit(id);
        // Suppress the event if this id was a stale cold-start entry we
        // proactively purged — forwarding it would end an unrelated active
        // call.
        if (id.isNotEmpty && _purgedStaleCallIds.remove(id)) {
          sl<AppLogger>().debug(
            'Suppressing echo end-event for purged stale call $id',
            tag: _tag,
          );
          if (_activeCallUUID == id) {
            _activeCallUUID = null;
            _activeCallData = null;
          }
          break;
        }
        _emit(id, 'endCall', _mergedData(extraMap));
        if (_activeCallUUID == id) {
          _activeCallUUID = null;
          _activeCallData = null;
        }
        _answeredCallIds.remove(id);
        break;

      case Event.actionCallToggleMute:
        final isMuted = body['isMuted'] == true;
        _emit(id, 'setMuted', {'muted': isMuted});
        break;

      case Event.actionCallStart:
        _activeCallUUID = id;
        break;

      case Event.actionCallCallback:
        // User tapped "Call back" on a missed-call notification.
        _emit(id, 'callBack', _mergedData(extraMap));
        break;

      default:
        // Other events (incoming shown, app open, hold, dtmf, etc.) — ignored.
        break;
    }
  }

  Map<String, dynamic>? _mergedData(Map<String, dynamic>? eventExtra) {
    if (_activeCallData == null && eventExtra == null) return null;
    return {
      ...?_activeCallData,
      ...?eventExtra,
    };
  }

  void _emit(String callUUID, String action, Map<String, dynamic>? data) {
    _callActionController.add(
      CallKitAction(callUUID: callUUID, action: action, data: data),
    );
  }

  /// Tell native to stop the FCM-service-owned ringtone and dismiss the
  /// incoming notification for [callId]. Best-effort fire-and-forget — the
  /// channel is only registered once [MainActivity.configureFlutterEngine]
  /// has run, so calls that race ahead of that simply throw and are
  /// swallowed (the cold-start path always reaches this point after the
  /// engine is up, since we got here via a plugin event).
  void _stopNativeCallKit(String callId) {
    if (!isAvailable) return;
    unawaited(
      _callKitChannel
          .invokeMethod<bool>('stopCallKit', {'callId': callId})
          .catchError((e) {
        sl<AppLogger>().debug('stopCallKit failed: $e', tag: _tag);
        return false;
      }),
    );
  }

  /// Awaits Firebase Auth, then emits an `answerCall` action. If auth never
  /// restores within the timeout we abandon the answer and free the dedup
  /// slot so the cold-start [_processColdStartActiveCalls] path (or a
  /// retry) can attempt again.
  Future<void> _emitAnswerWhenAuthReady(
    String callUUID,
    Map<String, dynamic>? data,
  ) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      sl<AppLogger>().debug(
        'actionCallAccept: waiting for Firebase Auth before emitting answer',
        tag: _tag,
      );
      final user = await _awaitAuthReady();
      if (user == null) {
        sl<AppLogger>().warning(
          'actionCallAccept: auth never restored — dropping answer for $callUUID',
          tag: _tag,
        );
        // Free the dedup slot so a retry / synth path may try again.
        _answeredCallIds.remove(callUUID);
        return;
      }
    }
    _emit(callUUID, 'answerCall', data);
  }

  /// Show a full-screen native incoming-call notification.
  ///
  /// [callId] is used as the CallKit UUID — pass a stable value (e.g. the
  /// Firestore room id) so subsequent `endCall(callId)` actually dismisses
  /// the right notification.
  ///
  /// [extra] is an arbitrary map passed back to Dart in the action callback
  /// (used to plumb caller_id/room_id through to acceptCallFromCallKit).
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required bool isVideo,
    String? callerAvatar,
    String? callerHandle,
    Map<String, dynamic>? extra,
    int durationSeconds = 30,
  }) async {
    if (!isAvailable) return;

    _activeCallUUID = callId;
    _activeCallData = extra;

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Greenhive',
      avatar: callerAvatar,
      handle: callerHandle ?? callerName,
      type: isVideo ? 1 : 0,
      duration: durationSeconds * 1000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: extra,
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Calls',
        missedCallNotificationChannelName: 'Missed Calls',
        isShowCallID: false,
      ),
    );

    sl<AppLogger>().debug(
      'showCallkitIncoming: id=$callId, caller=$callerName, video=$isVideo',
      tag: _tag,
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e, st) {
      sl<AppLogger>().error(
        'Failed to show CallKit',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Dismiss the native incoming/active call UI for [callId] (or current
  /// active call when null). Use this when the caller cancels.
  Future<void> endCall({String? callId}) async {
    if (!isAvailable) return;

    final id = callId ?? _activeCallUUID;
    if (id == null) {
      sl<AppLogger>().debug('endCall: no active call', tag: _tag);
      return;
    }

    sl<AppLogger>().debug('endCall: id=$id', tag: _tag);
    try {
      await FlutterCallkitIncoming.endCall(id);
    } catch (e) {
      sl<AppLogger>().error('Failed to end CallKit call', tag: _tag, error: e);
    }

    if (_activeCallUUID == id) {
      _activeCallUUID = null;
      _activeCallData = null;
    }
  }

  /// Convenience: dismiss every CallKit notification we may have shown.
  /// Useful from FCM background handlers when the call status changes.
  Future<void> endAllCalls() async {
    if (!isAvailable) return;
    sl<AppLogger>().debug('endAllCalls', tag: _tag);
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      sl<AppLogger>().error('Failed to end all CallKit calls', tag: _tag, error: e);
    }
    _activeCallUUID = null;
    _activeCallData = null;
  }

  /// Mark an outgoing/active call as connected. Optional — used to keep the
  /// call UI in the "ongoing" state for system-level integrations.
  Future<void> setCallConnected({String? callId}) async {
    if (!isAvailable) return;
    final id = callId ?? _activeCallUUID;
    if (id == null) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(id);
    } catch (_) {
      // Older versions of the package may not implement this — safe to ignore.
    }
  }

  /// Check if there is an active call tracked by this service.
  bool get hasActiveCall => _activeCallUUID != null;

  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _callActionController.close();
    _isInitialized = false;
    _instance = null;
  }
}
