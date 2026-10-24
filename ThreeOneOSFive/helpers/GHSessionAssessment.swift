import Foundation

/// Interprets the native stream result without treating a callback by itself
/// as proof of an authenticated and successfully completed RSD query.
/// A passing probe is NOT authorization to read or write any third-party data.
enum GHSessionAssessment {
    static func passed(receivedEvent: Bool, returnCode: Int32) -> Bool {
        receivedEvent && returnCode == 0
    }

    static func status(receivedEvent: Bool, returnCode: Int32) -> String {
        if returnCode != 0 {
            // Signed integer only; native error text and device identifiers are excluded.
            return "NATIVE_SESSION_RETURN_CODE_\(returnCode)_UNVERIFIED"
        }
        if !receivedEvent { return "NATIVE_SESSION_RC0_NO_EVENT_UNVERIFIED" }
        return "NATIVE_SYSLOG_EVENT_RECEIVED_NO_CONTENT"  // rc == 0 ONLY
    }
}
