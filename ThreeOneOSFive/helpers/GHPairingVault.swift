import Foundation
import Combine

/// Pairing records are sensitive device authentication credentials.
/// This vault stores user-selected local data only. It does NOT mark the device paired
/// or reuse records without verifying a real authenticated session first.
@MainActor
final class GHPairingVault: ObservableObject {
    @Published private(set) var statusCode: String = "PAIRING_NOT_IMPORTED"
    @Published private(set) var recordPresent: Bool = false
    private let maximumSize = 1024 * 1024

    init() { reload() }

    private var vaultURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("GHLocalPairing", isDirectory: true)
            .appendingPathComponent("pairing.record", isDirectory: false)
    }

    func reload() {
        let url = vaultURL
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        recordPresent = size > 0 && size <= maximumSize
        statusCode = recordPresent ? "PAIRING_FILE_STORED_NOT_AUTHENTICATED" : "PAIRING_NOT_IMPORTED"
    }

    func importFromFiles(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard !data.isEmpty && data.count <= maximumSize else {
                statusCode = "PAIRING_REJECTED_SIZE"; return
            }
            // Nonempty credentials are not the same as an authenticated pairing.
            // Import is opt-in and bytes never leave the device through this code.
            let target = vaultURL
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: target, options: [.atomic, .completeFileProtection])
            reload()
        } catch {
            statusCode = "PAIRING_IMPORT_FAILED"
            recordPresent = false
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: vaultURL)
        reload()
    }

    /// Deliberately not exposed: the imported credential is not yet authenticated.
    /// Any future adapter must prove a verified pairing handshake before use.
}
