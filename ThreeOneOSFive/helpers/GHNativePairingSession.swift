import Foundation
import Combine
import UIKit

/// Native RPPairing test backed by the embedded AirliftFFI.
/// Pairing records never leave the device, and the only session query is a
/// a read-only native session probe. Neither logs nor file paths are exported.
@MainActor
final class GHNativePairingSession: NSObject, ObservableObject, NetServiceDelegate {
    @Published private(set) var pairingCode = "NATIVE_PAIRING_NOT_STARTED"
    @Published private(set) var bonjourCode = "BONJOUR_NOT_STARTED"
    @Published private(set) var sessionCode = "SESSION_NOT_TESTED"
    @Published private(set) var presentedPIN = ""
    @Published private(set) var pairingInProgress = false
    @Published private(set) var sessionInProgress = false
    @Published private(set) var lastSessionAt = "NOT_TESTED"

    private var service: NetService?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private var inScope: Bool {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        guard os.majorVersion == 27, (0...2).contains(os.minorVersion) else { return false }
        if os.minorVersion == 2 {
            return ["24B5084k", "24B5089g"].contains(AppInfo.osBuild)
        }
        return true  // Test builds only, NOT proof of Patch support.
    }

    func start(vault: GHPairingVault) {
        guard inScope else { pairingCode = "BUILD_OUTSIDE_TEST_SCOPE"; return }
        guard !pairingInProgress else { return }
        guard let temporary = vault.prepareNativePairingOutput() else {
            pairingCode = "PAIRING_VAULT_PREPARATION_FAILED"; return
        }
        pairingInProgress = true
        presentedPIN = ""
        sessionCode = "SESSION_NOT_TESTED"
        pairingCode = "NATIVE_PAIRING_HOST_RUNNING"
        bonjourCode = "BONJOUR_WAITING_FOR_HOST"
        startShortBackgroundTask()

        GHStartNativeOnDevicePairing(temporary.path, { [weak self] id, port, txt in
            // Objective-C bridge callbacks may supply nil values to Swift.
            // Reject invalid native callbacks rather than force-unwrapping.
            guard let id = id, !id.isEmpty, let txt = txt else {
                self?.bonjourCode = "BONJOUR_INVALID_NATIVE_CALLBACK"
                return
            }
            self?.publishPairingService(id: id, port: port, txt: txt)
        }, { [weak self] pin in
            guard let pin = pin, !pin.isEmpty else {
                self?.pairingCode = "NATIVE_PIN_CALLBACK_INVALID"
                return
            }
            self?.presentedPIN = pin // PIN displayed locally, excluded from diagnostics.
            self?.pairingCode = "NATIVE_PIN_PROMPT_SHOWN"
        }, { [weak self] success, nativePath, rc in
            guard let self else { return }
            self.stopPairingAdvertising()
            self.finishShortBackgroundTask()
            self.pairingInProgress = false
            self.presentedPIN = ""
            // A nil/empty native path means the library used our supplied
            // temporary output path. The vault independently verifies its
            // location, size and successful persistence before reporting success.
            if success && vault.finalizeNativePairing(tempURL: temporary,
                                                       nativeResultPath: nativePath ?? "") {
                self.pairingCode = "NATIVE_PAIRING_RETURNED_SUCCESS_RECORD_STORED"
            } else {
                vault.discardTemporaryNativeRecord(temporary)
                self.pairingCode = success
                    ? "NATIVE_PAIRING_RECORD_INVALID"
                    : "NATIVE_PAIRING_ERROR_\(rc)"
            }
        })
    }

    func verifySelfReadOnly(vault: GHPairingVault) {
        guard inScope else { sessionCode = "BUILD_OUTSIDE_TEST_SCOPE"; return }
        guard !sessionInProgress && !pairingInProgress else { return }
        guard let path = vault.storedCredentialPath else {
            sessionCode = "NO_STORED_PAIRING_CREDENTIAL"; return
        }
        sessionInProgress = true
        sessionCode = "READ_ONLY_SYSLOG_SESSION_RUNNING"
        GHRunNativeReadOnlySessionProbe(path) { [weak self] succeeded, rc in
            guard let self else { return }
            self.sessionInProgress = false
            self.lastSessionAt = ISO8601DateFormatter().string(from: Date())
            // No syslog content was recorded. A received event does not grant write access.
            self.sessionCode = succeeded ? "NATIVE_SYSLOG_EVENT_RECEIVED_NO_CONTENT" : "NATIVE_SESSION_UNVERIFIED_\(rc)"
        }
    }

    private func publishPairingService(id: String, port: UInt16, txt: [String: Data]) {
        guard pairingInProgress else { return }
        service?.stop()
        // The service ID/TXT originate from the native pairing host, not a fake record.
        let announced = NetService(domain: "local.",
                                   type: "_remotepairing-pairable-host._tcp.",
                                   name: id, port: Int32(port))
        announced.delegate = self
        announced.setTXTRecord(NetService.data(fromTXTRecord: txt))
        announced.publish()
        service = announced
        bonjourCode = "BONJOUR_PUBLISHING"
    }

    // NetServiceDelegate requirements are nonisolated in modern SDKs.
    // Publish callbacks are marshalled to the actor that owns UI state.
    nonisolated func netServiceDidPublish(_ sender: NetService) {
        Task { @MainActor [weak self] in
            self?.bonjourCode = "BONJOUR_PUBLISHED"
        }
    }

    nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        Task { @MainActor [weak self] in
            self?.bonjourCode = "BONJOUR_PUBLISH_FAILED"
        }
    }

    private func stopPairingAdvertising() {
        service?.stop()
        service = nil
    }

    private func startShortBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "GooHanNativePairing") { [weak self] in
            Task { @MainActor in
                self?.finishShortBackgroundTask()
                // iOS background execution is limited. Never claim an active host
                // survived suspension or try to bypass platform restrictions.
                if self?.pairingInProgress == true { self?.pairingCode = "BACKGROUND_TIME_EXPIRED" }
            }
        }
    }

    private func finishShortBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    var safeReport: String {
        ["Native pairing: \(pairingCode)",
         "Pairing Bonjour: \(bonjourCode)",
         "Native read-only session: \(sessionCode)",
         "Session last checked: \(lastSessionAt)",
         "Session probe NEVER writes target files; result cannot authorize Patch."].joined(separator: "\n")
    }
}
