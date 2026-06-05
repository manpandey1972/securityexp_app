import Foundation
import UIKit
import FirebaseAuth
import FirebaseFunctions

/// Best-effort native rejectCall fired from the CallKit decline action so
/// the caller is notified within ~1–2s even when the Flutter engine isn't
/// running (cold-start incoming-call decline).
///
/// Mirrors the Android `InlineRejectDispatcher` / `RejectCallWorker`
/// pair: uses the cached Firebase Auth refresh token (rehydrated from
/// the keychain) to call the authenticated `api` callable with
/// `{action: "rejectCall", payload: {room_id}}`.
///
/// The server is idempotent — a duplicate reject after the in-app
/// Flutter path also fires returns `"already handled"` — so this is
/// safe to call alongside the existing Dart `_handleEnd` flow when
/// the app is alive.
///
/// IMPORTANT: invoked from `CXProviderDelegate` callbacks which run on
/// the **main queue** (we pass `queue: nil` to `provider.setDelegate`).
/// All blocking work must happen on a background queue, never on main —
/// in particular `DispatchQueue.main.sync` would self-deadlock.
final class InlineRejectDispatcher {
    static let shared = InlineRejectDispatcher()
    private init() {}

    private let authWaitTimeout: TimeInterval = 4.0
    private let authPollInterval: TimeInterval = 0.1
    private let overallTimeout: TimeInterval = 12.0
    private let workQueue = DispatchQueue(
        label: "com.goaegent.securityexperts.inlineReject",
        qos: .userInitiated
    )

    /// Fire-and-forget reject. Holds a `UIBackgroundTask` so the HTTPS
    /// call survives past `CXEndCallAction.fulfill()`.
    func dispatch(roomId: String) {
        guard !roomId.isEmpty else {
            NSLog("[InlineReject] refusing empty roomId")
            return
        }

        NSLog("[InlineReject] dispatch(roomId=%@)", roomId)

        // beginBackgroundTask is safe to call from any thread (including
        // main) and returns immediately. No need to bounce to main —
        // that would self-deadlock when called from a CXProvider
        // delegate (which already runs on the main queue).
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "InlineReject-\(roomId)") {
            NSLog("[InlineReject] background task expired for %@", roomId)
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        NSLog("[InlineReject] bgTask=%lu", UInt(bgTask.rawValue))

        let deadline = Date().addingTimeInterval(overallTimeout)
        let endBg: () -> Void = {
            if bgTask != .invalid {
                let id = bgTask
                bgTask = .invalid
                UIApplication.shared.endBackgroundTask(id)
                NSLog("[InlineReject] background task ended (%@)", roomId)
            }
        }

        workQueue.async { [weak self] in
            guard let self = self else { endBg(); return }

            self.awaitCurrentUser(until: deadline) { user in
                guard let user = user else {
                    NSLog("[InlineReject] no signed-in user — skipping rejectCall(%@)", roomId)
                    endBg()
                    return
                }
                NSLog("[InlineReject] auth ready (uid=%@)", user.uid)

                // Functions SDK attaches the ID token + App Check token
                // automatically and dispatches its completion on main.
                let callable = Functions.functions().httpsCallable("api")
                let payload: [String: Any] = [
                    "action": "rejectCall",
                    "payload": ["room_id": roomId]
                ]

                callable.call(payload) { _, error in
                    if let error = error {
                        let nsError = error as NSError
                        if nsError.domain == FunctionsErrorDomain,
                           let code = FunctionsErrorCode(rawValue: nsError.code),
                           code == .failedPrecondition {
                            NSLog("[InlineReject] rejectCall(%@) — already handled (idempotent)", roomId)
                        } else {
                            NSLog("[InlineReject] rejectCall(%@) failed: %@ (domain=%@ code=%ld)",
                                  roomId, error.localizedDescription, nsError.domain, nsError.code)
                        }
                    } else {
                        NSLog("[InlineReject] rejectCall(%@) succeeded", roomId)
                    }
                    endBg()
                }
            }
        }
    }

    /// Firebase Auth rehydrates `currentUser` lazily on cold start. Poll
    /// briefly so the call can authenticate even when the CallKit
    /// delegate raced the keychain load. Runs on the work queue; the
    /// completion is also invoked on the work queue.
    private func awaitCurrentUser(until deadline: Date, completion: @escaping (User?) -> Void) {
        if let user = Auth.auth().currentUser {
            completion(user)
            return
        }
        let waitDeadline = min(deadline, Date().addingTimeInterval(authWaitTimeout))
        func poll() {
            if let user = Auth.auth().currentUser {
                completion(user)
                return
            }
            if Date() >= waitDeadline {
                completion(Auth.auth().currentUser)
                return
            }
            workQueue.asyncAfter(deadline: .now() + authPollInterval) { poll() }
        }
        workQueue.asyncAfter(deadline: .now() + authPollInterval) { poll() }
    }
}
