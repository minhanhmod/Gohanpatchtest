import Foundation

/// Coordination only. This code does not implement the privileged AirLift transport.
/// Backends must independently enforce device/target authorization and provide safe backups.
public enum GHEngineID: String, Codable {
    case legacy = "DevicePatchService"
    case airlift = "AirLift"
}

public enum GHEnginePreference: String, Codable {
    case automatic
    case legacy
    case airlift
}

/// A driver MUST guarantee that `verifyReceipt` means durable, restorable success.
/// When apply throws after any write, the coordinator NEVER tries a second driver.
public struct GHPatchDriver {
    public let id: GHEngineID
    public let available: () -> Bool
    public let apply: () async throws -> Void
    public let verifyReceipt: () async throws -> Bool

    public init(id: GHEngineID,
                available: @escaping () -> Bool,
                apply: @escaping () async throws -> Void,
                verifyReceipt: @escaping () async throws -> Bool) {
        self.id = id
        self.available = available
        self.apply = apply
        self.verifyReceipt = verifyReceipt
    }
}

/// Only throw this BEFORE the engine has opened, created, overwritten, or deleted any target.
/// Any uncertainty about partial mutation MUST be reported as a normal error instead.
public struct GHNoWritePerformed: LocalizedError {
    public let reason: String
    /// A fixed, non-sensitive category. Never include target paths or server details.
    public let category: String
    public init(_ reason: String, category: String = "PREFLIGHT_UNCLASSIFIED") {
        self.reason = reason
        self.category = category
    }
    public var errorDescription: String? { reason }
}

public enum GHEngineFailure: LocalizedError {
    case alreadyRunning
    case unavailable(GHEngineID)
    case failed(GHEngineID, String)
    case preflightFailed(GHEngineID, String)
    case receiptMissing(GHEngineID)
    case receiptCheckFailed(GHEngineID, String)

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Một thao tác Patch khác đang chạy."
        case .unavailable(let id):
            return "Engine \(id.rawValue) chưa có trên bản IPA này hoặc không thể sử dụng."
        case .failed(let id, let message):
            return "\(id.rawValue) thất bại: \(message). Không tự động thử engine khác vì có thể đã ghi một phần dữ liệu."
        case .preflightFailed(let id, let message):
            return "\(id.rawValue) dừng trước khi ghi: \(message)"
        case .receiptMissing(let id):
            return "\(id.rawValue) chưa có biên nhận khôi phục hợp lệ. Trạng thái Patch chưa được xác nhận; không thử engine khác."
        case .receiptCheckFailed(let id, let message):
            return "Không kiểm tra được biên nhận sau \(id.rawValue): \(message)."
        }
    }
}

public struct GHEngineResult {
    public let selected: GHEngineID
    public let fallbackUsed: Bool
}

public struct GHEngineDiagnostic: Codable {
    public let timestamp: String
    public let engine: String
    public let phase: String
    public let detail: String
}

/// Serializes Patch apply calls and keeps a bounded, redacted diagnostic history.
/// No payload, target paths, license keys, tokens, or sensitive file contents are logged.
@MainActor
public final class GHPatchEngineCoordinator {
    public static let shared = GHPatchEngineCoordinator()
    private var inFlight = false
    public private(set) var events: [GHEngineDiagnostic] = []

    public init() {}

    // Error codes only; never include URLs, target paths, file names, or tokens.
    private func safeErrorCategory(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            return "Cocoa-\(nsError.code)"
        }
        if nsError.domain == NSPOSIXErrorDomain {
            return "POSIX-\(nsError.code)"
        }
        let typeName = String(reflecting: type(of: error))
        return typeName.contains("PatchPackageError") ? "PatchPackageError" : "OtherError"
    }

    public func clearDiagnostics() { events.removeAll() }

    public func diagnosticsJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(events)
    }

    private func record(_ engine: GHEngineID?, _ phase: String, _ detail: String) {
        // Use fixed, non-sensitive messages; never append Error.localizedDescription to stored logs.
        let stamp = ISO8601DateFormatter().string(from: Date())
        events.append(GHEngineDiagnostic(timestamp: stamp,
                                         engine: engine?.rawValue ?? "Coordinator",
                                         phase: phase,
                                         detail: detail))
        if events.count > 150 { events.removeFirst(events.count - 150) }
    }

    /// iOS 27 prefers AirLift when a *real* adapter is supplied and available.
    /// Other systems prefer the known working legacy engine. No version is declared
    /// supported solely because its major version matches this routing heuristic.
    public func apply(osMajorVersion: Int,
                      preference: GHEnginePreference = .automatic,
                      legacy: GHPatchDriver,
                      airlift: GHPatchDriver? = nil) async throws -> GHEngineResult {
        guard !inFlight else { throw GHEngineFailure.alreadyRunning }
        inFlight = true
        defer { inFlight = false }

        guard legacy.id == .legacy, airlift == nil || airlift?.id == .airlift else {
            throw GHEngineFailure.failed(.legacy, "Sai cấu hình driver")
        }

        let primary: GHPatchDriver
        let secondary: GHPatchDriver?
        switch preference {
        case .legacy:
            primary = legacy
            secondary = nil
        case .airlift:
            guard let adapter = airlift else {
                record(.airlift, "availability", "Adapter unavailable")
                throw GHEngineFailure.unavailable(.airlift)
            }
            primary = adapter
            secondary = nil
        case .automatic:
            if osMajorVersion >= 27, let adapter = airlift, adapter.available() {
                primary = adapter
                secondary = legacy
            } else {
                primary = legacy
                secondary = airlift
            }
        }

        guard primary.available() else {
            record(primary.id, "availability", "Primary unavailable")
            throw GHEngineFailure.unavailable(primary.id)
        }
        record(primary.id, "select", "Selected based on adapter availability")
        do {
            try await primary.apply()
        } catch let early as GHNoWritePerformed {
            record(primary.id, "prewrite", "Preflight failed [\(early.category)]; no write attempted")
            // ONLY this explicit error allows fallback. Never fallback on arbitrary failures.
            guard preference == .automatic, let other = secondary, other.available() else {
                throw GHEngineFailure.preflightFailed(primary.id, early.localizedDescription)
            }
            record(other.id, "fallback", "Safe pre-write fallback")
            do {
                try await other.apply()
            } catch {
                record(other.id, "apply", "Failure after apply started (\(safeErrorCategory(error))); write status unknown")
                throw GHEngineFailure.failed(other.id, error.localizedDescription)
            }
            do {
                guard try await other.verifyReceipt() else {
                    record(other.id, "verify", "Receipt missing")
                    throw GHEngineFailure.receiptMissing(other.id)
                }
            } catch let error as GHEngineFailure {
                throw error
            } catch {
                record(other.id, "verify", "Receipt verification threw")
                throw GHEngineFailure.receiptCheckFailed(other.id, error.localizedDescription)
            }
            record(other.id, "success", "Verified recovery receipt")
            return GHEngineResult(selected: other.id, fallbackUsed: true)
        } catch {
            record(primary.id, "apply", "Failure after apply started (\(safeErrorCategory(error))); write status unknown")
            throw GHEngineFailure.failed(primary.id, error.localizedDescription)
        }

        do {
            guard try await primary.verifyReceipt() else {
                record(primary.id, "verify", "Receipt missing")
                throw GHEngineFailure.receiptMissing(primary.id)
            }
        } catch let error as GHEngineFailure {
            throw error
        } catch {
            record(primary.id, "verify", "Receipt verification threw")
            throw GHEngineFailure.receiptCheckFailed(primary.id, error.localizedDescription)
        }
        record(primary.id, "success", "Verified recovery receipt")
        return GHEngineResult(selected: primary.id, fallbackUsed: false)
    }
}
