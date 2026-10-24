import Foundation

/// Pure outcome assessment, suitable for Swift tests without any iOS APIs.
enum GHV46NativeWriteAssessment {
    static func code(nativeRC: Int32, payloadVerified: Bool, restoreVerified: Bool,
                     cleanupVerified: Bool, pairingUnchanged: Bool, targetUnchanged: Bool) -> String {
        if !targetUnchanged { return "V46_NATIVE_REDIRECTED_FIXTURE_ABORT" }
        if !pairingUnchanged { return "V46_PAIRING_CHANGED_WHILE_NATIVE_WRITING" }
        if !restoreVerified { return "V46_RESTORE_FAILED_KEEP_FIXTURE" }
        if nativeRC != 0 { return "V46_NATIVE_WRITE_FAILED_RESTORED" }
        if !payloadVerified { return "V46_NATIVE_RC0_BUT_PAYLOAD_UNVERIFIED_RESTORED" }
        if !cleanupVerified { return "V46_FIXTURE_CLEANUP_FAILED" }
        return "V46_NATIVE_OWN_SANDBOX_WRITE_VERIFY_RESTORE_PASS_NOT_PATCH_DRIVER"
    }
}
