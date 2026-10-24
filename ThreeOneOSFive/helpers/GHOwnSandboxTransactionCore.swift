import Foundation

/// Self-owned fixture only. No AirLift APIs, entitlements or third-party paths.
/// The digest is injected for portability; the iOS UI supplies CryptoKit SHA256.
enum GHTransactionInjectedFault {
    case none
    case afterVerifiedBackup
    case afterReplacementWrite
}

struct GHTransactionResult {
    let code: String
    let backupVerified: Bool
    let replacementVerified: Bool
    let restoreVerified: Bool
    let cleanupVerified: Bool
    let attemptedRollback: Bool

    var passed: Bool {
        code == "V45_SELF_SANDBOX_BACKUP_WRITE_VERIFY_RESTORE_PASS" &&
        backupVerified && replacementVerified && restoreVerified && cleanupVerified
    }

    var safeReport: String {
        ["V4.5 transaction: \(code)",
         "Scope: OWN_APP_APPLICATION_SUPPORT_FIXTURE_ONLY",
         "Writer: FOUNDATION_ATOMIC_WRITE_NOT_AIRLIFT",
         "Digest: SHA256_ON_IOS",
         "Backup SHA verified: \(backupVerified ? "yes" : "no")",
         "Replacement SHA verified: \(replacementVerified ? "yes" : "no")",
         "Restore SHA verified: \(restoreVerified ? "yes" : "no")",
         "Cleanup verified: \(cleanupVerified ? "yes" : "no")",
         "Rollback attempted: \(attemptedRollback ? "yes" : "no")",
         "AIRLIFT_PATCH_DRIVER_MISSING; NO_THIRD_PARTY_WRITE_AUTHORIZATION"].joined(separator: "\n")
    }
}

/// The caller must provide a **fresh, empty, dedicated test root inside its own**
/// Application Support. This engine refuses an existing fixture directory,
/// making it impossible to silently replace a prior app/user file on retry.
enum GHOwnSandboxTransactionCore {
    static func run(testRoot: URL,
                    digest: (Data) -> String,
                    fault: GHTransactionInjectedFault = .none) -> GHTransactionResult {
        let fm = FileManager.default
        let target = testRoot.appendingPathComponent("gh_test_original.bin")
        let backup = testRoot.appendingPathComponent("gh_test_original.backup")
        var stage = "INIT"
        var backupOK = false
        var replacementOK = false
        var restoreOK = false
        var cleanupOK = false
        var rollbackAttempted = false
        var originalHash = ""
        do {
            // Never reuse/overwrite an existing directory. Caller creates a fresh UUID URL.
            guard !fm.fileExists(atPath: testRoot.path) else {
                return GHTransactionResult(code: "V45_REFUSED_EXISTING_TEST_DIRECTORY",
                                           backupVerified: false, replacementVerified: false,
                                           restoreVerified: false, cleanupVerified: false,
                                           attemptedRollback: false)
            }
            try fm.createDirectory(at: testRoot, withIntermediateDirectories: false)
            let nonce = UUID().uuidString
            let original = Data("GOOHAN_V45_TEST_ORIGINAL_\(nonce)".utf8)
            let replacement = Data("GOOHAN_V45_TEST_REPLACEMENT_\(nonce)".utf8)
            originalHash = digest(original)
            let replacementHash = digest(replacement)
            guard !originalHash.isEmpty && !replacementHash.isEmpty && originalHash != replacementHash else {
                throw GHTransactionError.digestInvalid
            }
            stage = "CREATE_FIXTURE"
            try original.write(to: target, options: .atomic)
            guard digest(try Data(contentsOf: target)) == originalHash else { throw GHTransactionError.checksumMismatch }

            stage = "BACKUP"
            try fm.copyItem(at: target, to: backup)
            backupOK = digest(try Data(contentsOf: backup)) == originalHash
            guard backupOK else { throw GHTransactionError.checksumMismatch }
            if case .afterVerifiedBackup = fault { throw GHTransactionError.injectedFault }

            stage = "REPLACE"
            try replacement.write(to: target, options: .atomic)
            if case .afterReplacementWrite = fault { throw GHTransactionError.injectedFault }
            stage = "VERIFY_REPLACEMENT"
            replacementOK = digest(try Data(contentsOf: target)) == replacementHash
            guard replacementOK else { throw GHTransactionError.checksumMismatch }

            stage = "RESTORE"
            let backupBytes = try Data(contentsOf: backup)
            guard digest(backupBytes) == originalHash else { throw GHTransactionError.checksumMismatch }
            try backupBytes.write(to: target, options: .atomic)
            restoreOK = digest(try Data(contentsOf: target)) == originalHash
            guard restoreOK else { throw GHTransactionError.checksumMismatch }

            stage = "CLEANUP"
            try fm.removeItem(at: testRoot)
            cleanupOK = !fm.fileExists(atPath: testRoot.path)
            guard cleanupOK else { throw GHTransactionError.cleanupFailed }
            return GHTransactionResult(code: "V45_SELF_SANDBOX_BACKUP_WRITE_VERIFY_RESTORE_PASS",
                                       backupVerified: backupOK, replacementVerified: replacementOK,
                                       restoreVerified: restoreOK, cleanupVerified: cleanupOK,
                                       attemptedRollback: false)
        } catch {
            // Do not delete evidence or claim success on failure. Attempt rollback
            // only when the backup was verified. Never touch any path beyond testRoot.
            if backupOK {
                rollbackAttempted = true
                if let backedUp = try? Data(contentsOf: backup),
                   digest(backedUp) == originalHash,
                   (try? backedUp.write(to: target, options: .atomic)) != nil,
                   let restored = try? Data(contentsOf: target) {
                    restoreOK = digest(restored) == originalHash
                }
            }
            let state = backupOK ? (restoreOK ? "ROLLED_BACK" : "ROLLBACK_UNVERIFIED") : "NO_VERIFIED_BACKUP"
            return GHTransactionResult(code: "V45_\(stage)_FAILED_\(state)",
                                       backupVerified: backupOK, replacementVerified: replacementOK,
                                       restoreVerified: restoreOK, cleanupVerified: false,
                                       attemptedRollback: rollbackAttempted)
        }
    }
}

private enum GHTransactionError: Error {
    case checksumMismatch, injectedFault, digestInvalid, cleanupFailed
}
