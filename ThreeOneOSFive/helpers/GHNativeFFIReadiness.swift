import Foundation
import Combine

/// Only confirms that the arm64 Rust FFI library is linked and callable.
/// A successful return is NOT proof of LocalDev connectivity, pairing or patch capability.
@MainActor
final class GHNativeFFIReadiness: ObservableObject {
    @Published private(set) var statusCode = "NOT_RUN"
    @Published private(set) var lastCheckedAt = ""

    func runLibrarySmokeTest() {
        let result = GHNativeLibrarySmokeTest()
        statusCode = result == 0 ? "NATIVE_FFI_CALL_OK_ONLY" : "NATIVE_FFI_RETURNED_ERROR_\(result)"
        lastCheckedAt = ISO8601DateFormatter().string(from: Date())
    }
}
