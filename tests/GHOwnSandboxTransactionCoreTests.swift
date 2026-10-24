import Foundation

@main
struct GHOwnSandboxTransactionCoreTests {
    // Test digest intentionally lightweight and platform-neutral. On iPhone
    // the actual diagnostic uses CryptoKit SHA256, asserted in wiring tests.
    static func digest(_ data: Data) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in data { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(hash, radix: 16)
    }

    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("GooHanV45SwiftTest_" + UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let okURL = root.appendingPathComponent("success")
        let ok = GHOwnSandboxTransactionCore.run(testRoot: okURL, digest: digest)
        assert(ok.passed)
        assert(!fm.fileExists(atPath: okURL.path))

        let afterBackup = root.appendingPathComponent("fault-backup")
        let r1 = GHOwnSandboxTransactionCore.run(testRoot: afterBackup, digest: digest,
                                                  fault: .afterVerifiedBackup)
        assert(!r1.passed && r1.attemptedRollback && r1.restoreVerified)
        assert(r1.code.contains("ROLLED_BACK"))
        assert(fm.fileExists(atPath: afterBackup.path))  // retain evidence on failure

        let afterWrite = root.appendingPathComponent("fault-write")
        let r2 = GHOwnSandboxTransactionCore.run(testRoot: afterWrite, digest: digest,
                                                  fault: .afterReplacementWrite)
        assert(!r2.passed && r2.attemptedRollback && r2.restoreVerified)
        assert(r2.code.contains("ROLLED_BACK"))
        assert(fm.fileExists(atPath: afterWrite.path))

        let existing = root.appendingPathComponent("do-not-overwrite")
        try fm.createDirectory(at: existing, withIntermediateDirectories: false)
        let existingFile = existing.appendingPathComponent("my-data.txt")
        try Data("unchanged".utf8).write(to: existingFile)
        let refused = GHOwnSandboxTransactionCore.run(testRoot: existing, digest: digest)
        assert(refused.code == "V45_REFUSED_EXISTING_TEST_DIRECTORY")
        let unchanged = try Data(contentsOf: existingFile)
        assert(unchanged == Data("unchanged".utf8))

        print("GHOwnSandboxTransactionCoreTests: PASS (success, 2 rollbacks, existing-data protection)")
    }
}
