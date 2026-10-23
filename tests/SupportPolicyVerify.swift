import Foundation
@main struct PolicyCheck {
    static func main() {
        precondition(ExploitSupportPolicy.isSupported(major: 18, minor: 6, patch: 0, build: "22G86"))
        precondition(ExploitSupportPolicy.isSupported(major: 27, minor: 0, patch: 0, build: "24A5355q"))
        precondition(!ExploitSupportPolicy.isSupported(major: 27, minor: 0, patch: 0, build: "24A777"))
        print("PASS: iOS18.6 accepted, known 27 beta accepted, unlisted 27.0 rejected")
    }
}
