import Foundation

@main struct TestRunner {
    static func main() {
        func assess(_ rc: Int32, _ p: Bool, _ r: Bool, _ c: Bool, _ unchanged: Bool, _ targetOK: Bool = true) -> String {
            GHV46NativeWriteAssessment.code(nativeRC: rc, payloadVerified: p,
                                             restoreVerified: r, cleanupVerified: c,
                                             pairingUnchanged: unchanged, targetUnchanged: targetOK)
        }
        assert(assess(0,true,true,true,true).contains("PASS_NOT_PATCH_DRIVER"))
        assert(assess(1,false,true,true,true) == "V46_NATIVE_WRITE_FAILED_RESTORED")
        assert(assess(0,false,true,true,true) == "V46_NATIVE_RC0_BUT_PAYLOAD_UNVERIFIED_RESTORED")
        assert(assess(0,true,false,false,true) == "V46_RESTORE_FAILED_KEEP_FIXTURE")
        assert(assess(0,true,true,true,false) == "V46_PAIRING_CHANGED_WHILE_NATIVE_WRITING")
        assert(assess(0,true,true,false,true) == "V46_FIXTURE_CLEANUP_FAILED")
        assert(assess(0,true,true,true,true,false) == "V46_NATIVE_REDIRECTED_FIXTURE_ABORT")
        print("PASS v4.6 native write assessment 7 cases")
    }
}
