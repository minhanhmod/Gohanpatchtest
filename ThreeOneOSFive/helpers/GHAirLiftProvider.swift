import Foundation

/// Injection point for a separately audited, authorized AirLift implementation.
/// UNCONFIGURED until the corresponding real native source has been incorporated,
/// compiled and tested with valid restoration receipts. Binary strings are not code.
/// `project` is the app's PatchProject; a provider implementation must check its
/// concrete type before use. Never fabricate a successful result or receipt.
@MainActor
public enum GHAirLiftProvider {
    public static var driverFactory: ((_ project: Any,
                                      _ receiptVerifier: @escaping () -> Bool) -> GHPatchDriver)?

    public static func configuredDriver(for project: Any,
                                        verifyReceipt: @escaping () -> Bool) -> GHPatchDriver? {
        guard let driver = driverFactory?(project, verifyReceipt), driver.id == .airlift else {
            return nil
        }
        return driver
    }
}
