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
    @Published private(set) var sessionPassed = false
    @Published private(set) var nativeSessionReturnCode = "NOT_TESTED"
    @Published private(set) var ownContainerCode = "OWN_CONTAINER_NOT_TESTED"
    @Published private(set) var ownContainerInProgress = false
    @Published private(set) var lastOwnContainerAt = "NOT_TESTED"
    private var verifiedCredentialRevision: UUID?

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
        guard !pairingInProgress && !sessionInProgress && !ownContainerInProgress else { return }
        invalidateSessionState()
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
        guard !sessionInProgress && !pairingInProgress && !ownContainerInProgress else { return }
        guard let path = vault.storedCredentialPath else {
            sessionCode = "NO_STORED_PAIRING_CREDENTIAL"; return
        }
        sessionInProgress = true
        invalidateSessionState()
        sessionCode = "READ_ONLY_SYSLOG_SESSION_RUNNING"
        let testedCredentialRevision = vault.credentialRevision
        GHRunNativeReadOnlySessionProbe(path) { [weak self] succeeded, rc in
            guard let self else { return }
            self.sessionInProgress = false
            self.lastSessionAt = ISO8601DateFormatter().string(from: Date())
            // Require both native rc == 0 and a real event. An event alone
            // was incorrectly considered sufficient in v4.3.
            self.nativeSessionReturnCode = String(rc)
            self.sessionCode = GHSessionAssessment.status(receivedEvent: succeeded, returnCode: rc)
            self.sessionPassed = GHSessionAssessment.passed(receivedEvent: succeeded, returnCode: rc)
                && testedCredentialRevision == vault.credentialRevision
            self.verifiedCredentialRevision = self.sessionPassed ? testedCredentialRevision : nil
            if !self.sessionPassed && testedCredentialRevision != vault.credentialRevision {
                self.sessionCode = "PAIRING_CHANGED_DURING_SESSION"
            }
        }
    }

    /// Published state is only valid for the exact credential revision that
    /// passed the native read-only session check.
    func sessionValid(for vault: GHPairingVault) -> Bool {
        sessionPassed && verifiedCredentialRevision == vault.credentialRevision
    }

    /// Native lookup is constrained by the Objective-C bridge to this app's
    /// exact bundle identifier, and then compared to NSHomeDirectory().
    /// No third-party container or patch path is accepted.
    func testOwnContainerReadOnly(vault: GHPairingVault) {
        guard inScope else { ownContainerCode = "BUILD_OUTSIDE_TEST_SCOPE"; return }
        guard !ownContainerInProgress && !sessionInProgress && !pairingInProgress else { return }
        guard sessionValid(for: vault) else {
            ownContainerCode = "VERIFIED_SESSION_REQUIRED"
            sessionPassed = false
            return
        }
        guard let path = vault.storedCredentialPath,
              let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            ownContainerCode = "SELF_ID_OR_PAIRING_MISSING"; return
        }
        ownContainerInProgress = true
        ownContainerCode = "NATIVE_OWN_CONTAINER_LOOKUP_RUNNING"
        // Lookup is blocking inside the vendor FFI. There is no safe native
        // cancellation API; never start a second lookup while one is pending.
        // If it takes longer than 20 seconds, report that it is still running.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            if self?.ownContainerInProgress == true {
                self?.ownContainerCode = "NATIVE_OWN_CONTAINER_LOOKUP_SLOW_STILL_RUNNING"
            }
        }
        GHRunNativeOwnContainerReadProbe(path, bundleID) { [weak self] matched, readable, rc in
            guard let self else { return }
            self.ownContainerInProgress = false
            self.lastOwnContainerAt = ISO8601DateFormatter().string(from: Date())
            guard self.verifiedCredentialRevision == vault.credentialRevision else {
                self.invalidateSessionState()
                self.ownContainerCode = "PAIRING_CHANGED_DURING_CONTAINER_CHECK"
                return
            }
            if rc != 0 {
                self.ownContainerCode = "NATIVE_CONTAINER_LOOKUP_RC_\(rc)"
            } else if !matched {
                self.ownContainerCode = "NATIVE_CONTAINER_PATH_NOT_OWN_SANDBOX"
            } else if !readable {
                self.ownContainerCode = "NATIVE_OWN_CONTAINER_READ_DENIED"
            } else {
                self.ownContainerCode = "NATIVE_OWN_CONTAINER_READ_ONLY_OK"
            }
        }
    }

    private func invalidateSessionState() {
        sessionPassed = false
        verifiedCredentialRevision = nil
        nativeSessionReturnCode = "NOT_TESTED"
        ownContainerCode = "OWN_CONTAINER_NOT_TESTED"
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

    func safeReport(for vault: GHPairingVault) -> String {
        ["Native pairing: \(pairingCode)",
         "Pairing Bonjour: \(bonjourCode)",
         "Native read-only session: \(sessionCode)",
         "Session native rc: \(nativeSessionReturnCode)",
         "Session strict pass (rc0 + event + unchanged credential): \(sessionValid(for: vault) ? "yes" : "no")",
         "Session last checked: \(lastSessionAt)",
         "Native self-container lookup: \(ownContainerCode)",
         "Own container last checked: \(lastOwnContainerAt)",
         "V4.4 PATCH GATE: AIRLIFT_PATCH_DRIVER_MISSING",
         "Read-only probes never authorize Patch or third-party container access."].joined(separator: "\n")
    }
}
