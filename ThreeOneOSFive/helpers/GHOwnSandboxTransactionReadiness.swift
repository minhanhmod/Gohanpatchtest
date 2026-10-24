import Foundation
import SwiftUI
import CryptoKit

/// v4.5 diagnostic: atomic writes only inside GooHan's OWN Application Support.
/// This does not make AirLift a patch writer or open other app containers.
@MainActor
final class GHOwnSandboxTransactionReadiness: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var resultCode = "V45_NOT_TESTED"
    @Published private(set) var normalPass = false
    @Published private(set) var backupFaultRollbackPass = false
    @Published private(set) var writeFaultRollbackPass = false
    @Published private(set) var report = "V4.5 chưa chạy. Chỉ ghi fixture của GooHan, không ghi Patch."
    @Published private(set) var lastCheckedAt = "NOT_TESTED"

    func run(fault: GHTransactionInjectedFault = .none) {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(for: .applicationSupportDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: true)
            let dedicatedParent = appSupport.appendingPathComponent("GHV45OwnSandboxFixtures", isDirectory: true)
            try fm.createDirectory(at: dedicatedParent, withIntermediateDirectories: true)
            let testRoot = dedicatedParent.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let result = GHOwnSandboxTransactionCore.run(testRoot: testRoot, digest: { data in
                SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            }, fault: fault)
            resultCode = result.code
            report = result.safeReport
            switch fault {
            case .none:
                normalPass = result.passed
            case .afterVerifiedBackup:
                backupFaultRollbackPass = !result.passed && result.attemptedRollback && result.restoreVerified
            case .afterReplacementWrite:
                writeFaultRollbackPass = !result.passed && result.attemptedRollback && result.restoreVerified
            }
        } catch {
            // No paths, pairing records, license keys, data or identifiers in reports.
            resultCode = "V45_OWN_APPLICATION_SUPPORT_UNAVAILABLE"
            report = "V4.5 transaction: \(resultCode)\nWriter: FOUNDATION_ONLY\nAIRLIFT_PATCH_DRIVER_MISSING"
        }
        lastCheckedAt = ISO8601DateFormatter().string(from: Date())
    }

    var allSandboxChecksPassed: Bool {
        normalPass && backupFaultRollbackPass && writeFaultRollbackPass
    }

    var safeReport: String {
        report + "\nV4.5 baseline roundtrip passed: " + (normalPass ? "yes" : "no")
        + "\nV4.5 rollback after backup passed: " + (backupFaultRollbackPass ? "yes" : "no")
        + "\nV4.5 rollback after write passed: " + (writeFaultRollbackPass ? "yes" : "no")
        + "\nV4.5 overall: " + (allSandboxChecksPassed ? "V45_SELF_SANDBOX_ALL_TESTS_PASS_AIRLIFT_NOT_TESTED" : "V45_SELF_SANDBOX_TESTS_INCOMPLETE")
        + "\nV4.5 last tested: " + lastCheckedAt
    }
}
