import Foundation
import Combine
import CryptoKit

/// v4.6: explicit native AirLift write test restricted to a disposable fixture in
/// this application's own sandbox. Not an AirLift Patch Driver.
/// All file operations are local, and the opaque FFI is called off-main-thread.
@MainActor
final class GHV46NativeWriteReadiness: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var resultCode = "V46_NOT_TESTED"
    @Published private(set) var nativeReturnCode = "NOT_RUN"
    @Published private(set) var nativeErrorCategory = "NOT_RUN"
    @Published private(set) var nativeTraceHint = "NOT_RUN"
    @Published private(set) var nativeTraceBreakdown = "NOT_RUN"
    @Published private(set) var nativePhase = "NOT_STARTED"
    @Published private(set) var nativeDurationMs = "NOT_RUN"
    @Published private(set) var baselineVerified = false
    @Published private(set) var stagingSHA256Verified = false
    @Published private(set) var backupVerified = false
    @Published private(set) var nativeWriteVerified = false
    @Published private(set) var restoreVerified = false
    @Published private(set) var cleanupVerified = false
    @Published private(set) var lastCheckedAt = "NOT_TESTED"

    private static func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Only offered after v4.4 strict session + own container and all v4.5
    /// Foundation roundtrip tests have passed during this app session.
    func run(vault: GHPairingVault,
             nativeSession: GHNativePairingSession,
             v45: GHOwnSandboxTransactionReadiness) {
        guard !isRunning else { return }
        guard nativeSession.sessionValid(for: vault),
              nativeSession.ownContainerCode == "NATIVE_OWN_CONTAINER_READ_ONLY_OK",
              v45.allSandboxChecksPassed,
              let pairingPath = vault.storedCredentialPath else {
            resultCode = "V46_READINESS_GATE_NOT_PASSED"
            return
        }
        baselineVerified = false
        stagingSHA256Verified = false
        backupVerified = false
        nativeWriteVerified = false
        restoreVerified = false
        cleanupVerified = false
        nativeReturnCode = "NOT_RUN"
        nativeErrorCategory = "NOT_RUN"
        nativeTraceHint = "NOT_RUN"
        nativeTraceBreakdown = "NOT_RUN"
        nativePhase = "FIXTURE_PREPARATION"
        nativeDurationMs = "NOT_RUN"

        let fm = FileManager.default
        let revision = vault.credentialRevision
        do {
            let support = try fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil, create: true)
            let parent = support.appendingPathComponent("GHV46NativeFixtures", isDirectory: true)
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
            let root = parent.appendingPathComponent(UUID().uuidString, isDirectory: true)
            guard !fm.fileExists(atPath: root.path) else {
                resultCode = "V46_REFUSED_EXISTING_FIXTURE"
                return
            }
            try fm.createDirectory(at: root, withIntermediateDirectories: false)
            let stage = root.appendingPathComponent("stage", isDirectory: true)
            let target = root.appendingPathComponent("target", isDirectory: true)
            try fm.createDirectory(at: stage, withIntermediateDirectories: false)
            try fm.createDirectory(at: target, withIntermediateDirectories: false)
            let targetFile = target.appendingPathComponent("gh_v46_fixture.dat")
            let stageFile = stage.appendingPathComponent("gh_v46_fixture.dat")
            let backup = root.appendingPathComponent("gh_v46_fixture.backup")
            let original = Data("GOOHAN_V46_ORIGINAL_\(UUID().uuidString)".utf8)
            let replacement = Data("GOOHAN_V46_AIRLIFT_\(UUID().uuidString)".utf8)
            let originalDigest = Self.sha(original)
            let replacementDigest = Self.sha(replacement)
            guard originalDigest != replacementDigest else {
                resultCode = "V46_DIGEST_COLLISION"
                return
            }
            try original.write(to: targetFile, options: [.atomic, .completeFileProtection])
            try replacement.write(to: stageFile, options: [.atomic, .completeFileProtection])
            // Validate the *local* source file independently from the opaque
            // AirLift library. It may still reject an on-device destination.
            stagingSHA256Verified = Self.sha(try Data(contentsOf: stageFile)) == replacementDigest
            guard stagingSHA256Verified else {
                resultCode = "V46_LOCAL_STAGING_SHA256_FAILED"
                return
            }
            baselineVerified = Self.sha(try Data(contentsOf: targetFile)) == originalDigest
            guard baselineVerified else {
                resultCode = "V46_BASELINE_NOT_VERIFIED"
                return
            }
            try original.write(to: backup, options: [.atomic, .completeFileProtection])
            backupVerified = Self.sha(try Data(contentsOf: backup)) == originalDigest
            guard backupVerified else {
                resultCode = "V46_BACKUP_NOT_VERIFIED"
                return
            }
            isRunning = true
            resultCode = "V46_NATIVE_AIRLIFT_WRITE_RUNNING"
            nativePhase = "FFI_CALL_IN_PROGRESS"
            let nativeStartedAt = Date()
            let expectedCanonicalTarget = targetFile.resolvingSymlinksInPath().standardizedFileURL.path

            // Native code rechecks the exact self-sandbox root and only accepts
            // stage/gh_v46_fixture.dat -> target/gh_v46_fixture.dat.
            GHRunNativeOwnFixtureWrite(pairingPath, root.path) { [self] accepted, rc, errorCategory, traceHint in
                self.nativeErrorCategory = errorCategory
                let redactedTrace = traceHint.components(separatedBy: "|")
                self.nativeTraceHint = redactedTrace.first ?? "AL_TRACE_NOT_REPORTED"
                self.nativeTraceBreakdown = redactedTrace.dropFirst().joined(separator: "\n")
                if self.nativeTraceBreakdown.isEmpty {
                    self.nativeTraceBreakdown = "AL_TRACE_COUNTERS_UNAVAILABLE"
                }
                self.nativeDurationMs = String(Int(Date().timeIntervalSince(nativeStartedAt) * 1000))
                self.nativePhase = rc == 0 ? "FFI_RETURNED_RC_0" : "FFI_RETURNED_NONZERO"
                self.nativeReturnCode = String(rc)
                // Verify the native writer has NOT replaced our destination with
                // a symlink or redirected its parent before any Foundation write.
                let targetUnchanged = targetFile.resolvingSymlinksInPath().standardizedFileURL.path
                    == expectedCanonicalTarget
                // Native rc==0 alone is not evidence of a verified write.
                if targetUnchanged, let current = try? Data(contentsOf: targetFile) {
                    self.nativeWriteVerified = accepted && rc == 0 &&
                        Self.sha(current) == replacementDigest
                }
                // Restore even on native errors, but never follow a redirected path.
                // A retained callback ensures rollback still runs after a view reload.
                if targetUnchanged,
                   let backupBytes = try? Data(contentsOf: backup),
                   Self.sha(backupBytes) == originalDigest {
                    do {
                        try backupBytes.write(to: targetFile, options: [.atomic, .completeFileProtection])
                        self.restoreVerified = Self.sha(try Data(contentsOf: targetFile)) == originalDigest
                    } catch {
                        self.restoreVerified = false
                    }
                }
                if self.restoreVerified {
                    try? fm.removeItem(at: root)
                    self.cleanupVerified = !fm.fileExists(atPath: root.path)
                }
                self.resultCode = GHV46NativeWriteAssessment.code(
                    nativeRC: rc,
                    payloadVerified: self.nativeWriteVerified,
                    restoreVerified: self.restoreVerified,
                    cleanupVerified: self.cleanupVerified,
                    pairingUnchanged: revision == vault.credentialRevision,
                    targetUnchanged: targetUnchanged
                )
                self.nativePhase = self.restoreVerified
                    ? (self.nativeWriteVerified ? "COMPLETE_NATIVE_VERIFIED_RESTORED" : "COMPLETE_NATIVE_UNVERIFIED_RESTORED")
                    : "COMPLETE_RESTORE_UNVERIFIED"
                self.lastCheckedAt = ISO8601DateFormatter().string(from: Date())
                self.isRunning = false
            }
        } catch {
            nativePhase = "LOCAL_FIXTURE_PREPARATION_FAILED"
            resultCode = "V46_FIXTURE_PREPARATION_FAILED"
            lastCheckedAt = ISO8601DateFormatter().string(from: Date())
        }
    }

    var safeReport: String {
        ["V4.6 native AirLift own-sandbox write test: \(resultCode)",
         "Scope: OWN_APP_APPLICATION_SUPPORT_DISPOSABLE_FIXTURE_ONLY",
         "Writer: AIRLIFT_NATIVE_al_exploit_write_dir_SELF_ONLY",
         "Native rc: \(nativeReturnCode)",
         "Native error class (redacted): \(nativeErrorCategory)",
         "Native trace hint (redacted): \(nativeTraceHint)",
         "Native trace counters (redacted): \(nativeTraceBreakdown)",
         "Native phase: \(nativePhase)",
         "Native call duration ms: \(nativeDurationMs)",
         "Local staging SHA256 verified: \(stagingSHA256Verified ? "yes" : "no")",
         "Baseline verified: \(baselineVerified ? "yes" : "no")",
         "Backup verified: \(backupVerified ? "yes" : "no")",
         "Native replacement SHA verified: \(nativeWriteVerified ? "yes" : "no")",
         "Original restored SHA verified: \(restoreVerified ? "yes" : "no")",
         "Fixture cleaned: \(cleanupVerified ? "yes" : "no")",
         "Last checked: \(lastCheckedAt)",
         "AIRLIFT_PATCH_DRIVER_MISSING; NO_THIRD_PARTY_WRITE"].joined(separator: "\n")
    }
}
