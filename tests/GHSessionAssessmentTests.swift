import Foundation

@main
struct GHSessionAssessmentTests {
    static func main() {
        assert(GHSessionAssessment.passed(receivedEvent: true, returnCode: 0))
        assert(!GHSessionAssessment.passed(receivedEvent: false, returnCode: 0))
        assert(!GHSessionAssessment.passed(receivedEvent: true, returnCode: -1))
        assert(!GHSessionAssessment.passed(receivedEvent: false, returnCode: -2))
        assert(GHSessionAssessment.status(receivedEvent: true, returnCode: 0) == "NATIVE_SYSLOG_EVENT_RECEIVED_NO_CONTENT")
        assert(GHSessionAssessment.status(receivedEvent: true, returnCode: 9) == "NATIVE_SESSION_RETURN_CODE_9_UNVERIFIED")
        assert(GHSessionAssessment.status(receivedEvent: false, returnCode: 0) == "NATIVE_SESSION_RC0_NO_EVENT_UNVERIFIED")
        print("GHSessionAssessmentTests: PASS")
    }
}
