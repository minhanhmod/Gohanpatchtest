import Foundation

/// Adapter to the existing, proven backup/restore implementation.
/// IMPORTANT: The native AirLift implementation is NOT included in this repository.
/// Never claim iOS 27 compatibility or register an AirLift backend without
/// complete read/write permission checks AND compatible restore receipts.
@MainActor
enum GHInstalledPatchEngine {
    // An AirLift adapter is NOT bundled here. This flag is true only when a
    // future audited native implementation explicitly registers its factory.
    // A registered factory is still checked per project for actual availability.
    static var airLiftReady: Bool { GHAirLiftProvider.driverFactory != nil }

    static func apply(project: PatchProject,
                      preference: GHEnginePreference) async throws -> GHEngineResult {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        // Never route a non-verified OS build to the old kernel/container path,
        // even as an automatic fallback after a future AirLift pre-write failure.
        let legacyVerified = ExploitSupportPolicy.isSupported(
            major: os.majorVersion,
            minor: os.minorVersion,
            patch: os.patchVersion,
            build: AppInfo.osBuild
        )
        let legacy = GHPatchDriver(
            id: .legacy,
            available: { legacyVerified },
            apply: {
                // Failure during this read-only check is definitely pre-write.
                // Do not mistake unresolved containers for a partial write.
                do {
                    try await Task.detached(priority: .userInitiated) {
                        try DevicePatchService.preflight(project: project)
                    }.value
                } catch let error as PatchPackageError {
                    if case .targetAppUnavailable = error {
                        throw GHNoWritePerformed(
                            "Không tìm được container của ứng dụng đích. Hãy kiểm tra cài đặt ứng dụng, quyền truy cập và log MHA-C2.",
                            category: "TARGET_CONTAINER_UNRESOLVED"
                        )
                    }
                    throw GHNoWritePerformed(
                        "Kiểm tra container trước khi ghi thất bại; chưa áp dụng Patch.",
                        category: "PATCH_PACKAGE_PREFLIGHT_ERROR"
                    )
                } catch {
                    throw GHNoWritePerformed(
                        "Không hoàn tất được kiểm tra container trước khi ghi; chưa áp dụng Patch.",
                        category: "CONTAINER_PREFLIGHT_ERROR"
                    )
                }
                _ = try await Task.detached(priority: .userInitiated) {
                    try DevicePatchService.apply(project: project)
                }.value
            },
            verifyReceipt: {
                DevicePatchService.latestReceipt(projectID: project.id) != nil
            }
        )
        // No AirLift adapter ships in this ZIP. A future native implementation
        // must register a real provider and use compatible recovery receipts.
        let airlift = GHAirLiftProvider.configuredDriver(
            for: project,
            verifyReceipt: {
                DevicePatchService.latestReceipt(projectID: project.id) != nil
            }
        )
        return try await GHPatchEngineCoordinator.shared.apply(
            osMajorVersion: os.majorVersion,
            preference: preference,
            legacy: legacy,
            airlift: airlift
        )
    }

    static func deviceSummary() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let build = AppInfo.osBuild
        let supported = ExploitSupportPolicy.isSupported(
            major: os.majorVersion,
            minor: os.minorVersion,
            patch: os.patchVersion,
            build: build
        )
        let systemTag: String
        if os.majorVersion == 27 && build == "24A437" {
            systemTag = " | iOS 27.0 build 24A437 (chưa xác minh engine cũ)"
        } else if os.majorVersion == 27 && build == "24A435" {
            systemTag = " | iOS 27.0 build 24A435 (chưa xác minh engine cũ)"
        } else {
            systemTag = ""
        }
        let airliftTag = airLiftReady
            ? "đã đăng ký nhà cung cấp (cần xác minh trên thiết bị)"
            : "chưa tích hợp native"
        return "iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion) | build \(build)\(systemTag) | engine cũ đã xác minh: \(supported ? "có" : "không") | AirLift: \(airliftTag) | Pair File: chưa hỗ trợ trong GooHan hiện tại"
    }

    static func diagnosticsText() -> String {
        let events = GHPatchEngineCoordinator.shared.events
        let rows = events.map { "\($0.timestamp) | \($0.engine) | \($0.phase) | \($0.detail)" }
        return (["GooHan Patch – Chẩn đoán engine", deviceSummary()] + rows).joined(separator: "\n")
    }
}
