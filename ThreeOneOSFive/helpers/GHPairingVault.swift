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

    /// Native engine may create a record only in our private Application Support tree.
    /// A successful file write is not a verified device session.
    func prepareNativePairingOutput() -> URL? {
        let folder = vaultURL.deletingLastPathComponent()
        guard (try? FileManager.default.createDirectory(at: folder,
                        withIntermediateDirectories: true)) != nil else { return nil }
        return folder.appendingPathComponent("temporary-\(UUID().uuidString).plist")
    }

    func discardTemporaryNativeRecord(_ url: URL) {
        guard url.deletingLastPathComponent().standardizedFileURL == vaultURL.deletingLastPathComponent().standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Only invoked on an actual rc==0 native pairing result. Do not trust a
    /// path returned by a library if it escapes the private storage directory.
    func finalizeNativePairing(tempURL: URL, nativeResultPath: String) -> Bool {
        let parent = vaultURL.deletingLastPathComponent().standardizedFileURL
        let result = nativeResultPath.isEmpty ? tempURL : URL(fileURLWithPath: nativeResultPath)
        let standardized = result.standardizedFileURL
        guard standardized.deletingLastPathComponent() == parent else { return false }
        defer { discardTemporaryNativeRecord(tempURL) }
        guard let data = try? Data(contentsOf: standardized),
              data.count > 0, data.count <= maximumSize else { return false }
        do {
            try data.write(to: vaultURL, options: [.atomic, .completeFileProtection])
            if standardized != tempURL { try? FileManager.default.removeItem(at: standardized) }
            reload()
            return recordPresent
        } catch { return false }
    }

    /// Only for this app's explicit, read-only native test. Do not expose in logs.
    var storedCredentialPath: String? {
        reload()
        return recordPresent ? vaultURL.path : nil
    }

    /// Deliberately not exposed: the imported credential is not yet authenticated.
    /// Any future adapter must prove a verified pairing handshake before use.
}
