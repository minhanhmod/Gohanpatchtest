import Foundation

/// Read-only iOS 27 readiness report. This deliberately does NOT probe pairing
/// credentials or claim to control another app's VPN tunnel.
struct GHLocalDevReadiness {
    let major: Int
    let minor: Int
    let build: String
    let userConfirmedLocalDev: Bool
    let nativeAirLiftRegistered: Bool

    var inIOS27InvestigationRange: Bool {
        major == 27 && minor >= 0 && minor <= 2
    }

    var buildNote: String {
        guard major == 27 else { return "Ngoài phạm vi chẩn đoán iOS 27" }
        if build == "24A435" { return "iOS 27.0 RC — cần kiểm thử riêng" }
        if build == "24A437" { return "iOS 27.0 chính thức — cần kiểm thử riêng" }
        if minor == 2 {
            return "iOS 27.2 — kiểm tra build cụ thể; một số bản beta đã vá cơ chế AirLift"
        }
        return "Build chưa được xác minh cho engine mới"
    }

    var code: String {
        guard inIOS27InvestigationRange else { return "OUTSIDE_IOS27_SCOPE" }
        guard nativeAirLiftRegistered else { return "NATIVE_AIRLIFT_MISSING" }
        guard userConfirmedLocalDev else { return "LOCALDEV_NOT_USER_CONFIRMED" }
        return "NATIVE_PRESENT_DEVICE_VALIDATION_REQUIRED"
    }

    var report: String {
        let local = userConfirmedLocalDev
            ? "người dùng xác nhận đã bật (GooHan chưa xác minh kết nối)"
            : "chưa được người dùng xác nhận"
        let native = nativeAirLiftRegistered
            ? "đã đăng ký provider, chưa chứng minh hoạt động"
            : "chưa tích hợp mã native"
        return "Chẩn đoán iOS 27 | build \(build) | \(buildNote)\n"
            + "LocalDevVPN: \(local)\n"
            + "AirLift: \(native)\n"
            + "Trạng thái: \(code)\n"
            + "Lưu ý: Kết nối VPN, File Pair hoặc số phiên bản iOS không tự cấp quyền truy cập container."
    }
}


/// Diagnostic gate only. Observations in another app are self-reported, never
/// proof that GooHan holds a pairing credential or has AirLift write access.
/// Even a fully satisfied precondition report cannot authorize patching.
struct GHFinalTestGate {
    let major: Int
    let minor: Int
    let build: String
    let probeCode: String
    let userConfirmedLocalDev: Bool
    let beta5TunnelObserved: Bool
    let beta5PairingObserved: Bool
    let beta5PatchObserved: Bool
    let nativeAirLiftRegistered: Bool

    var resultCode: String {
        guard major == 27 && (0...2).contains(minor) else { return "OUT_OF_TEST_SCOPE" }
        // Verified candidate builds for this diagnostic scope, not a claim of patch support.
        // Beta 3 and later must never be labelled within the requested test range.
        if minor == 2 && build != "24B5084k" && build != "24B5089g" {
            return "IOS27_2_BUILD_OUTSIDE_BETA_1_2_SCOPE"
        }
        guard probeCode != "NOT_TESTED" && probeCode != "RUNNING" else {
            return "READ_ONLY_TCP_TEST_REQUIRED"
        }
        guard userConfirmedLocalDev else { return "LOCALDEV_NOT_USER_CONFIRMED" }
        guard beta5TunnelObserved else { return "BETA5_TUNNEL_NOT_OBSERVED" }
        guard beta5PairingObserved else { return "BETA5_PAIRING_NOT_OBSERVED" }
        guard beta5PatchObserved else { return "BETA5_PATCH_NOT_OBSERVED" }
        // A non-responding sample endpoint isn't a definitive absence of LocalDev.
        // Preserve the observation without inferring that pairing is invalid.
        guard nativeAirLiftRegistered else { return "NATIVE_AIRLIFT_IMPLEMENTATION_REQUIRED" }
        return "NATIVE_DRIVER_REQUIRES_AUTH_AND_RESTORE_TEST"
    }

    var report: String {
        return [
            "GooHan iOS 27 - Final prerequisite test v3.3",
            "iOS major/minor: \(major).\(minor) | build: \(build)",
            "Test scope: 27.0–27.2 beta 2 (27.2 requires exact build verification)",
            "LocalDevVPN user confirmation: \(userConfirmedLocalDev ? "yes (manual)" : "no")",
            "Local sample TCP routes: \(probeCode) (not authentication)",
            "3105 Beta 5 tunnel: \(beta5TunnelObserved ? "reported active" : "not reported")",
            "3105 Beta 5 pairing: \(beta5PairingObserved ? "reported ready" : "not reported")",
            "3105 Beta 5 same-device patch: \(beta5PatchObserved ? "reported successful" : "not reported")",
            "GooHan native AirLift provider: \(nativeAirLiftRegistered ? "registered; needs validation" : "missing")",
            "Next blocker: \(resultCode)",
            "SECURITY: do not share pairing records, PINs, device IDs, license keys or target file paths.",
            "NOTE: pairing and patch states above are user reports from 3105, not verified in GooHan.",
            "NOTE: this diagnostic never authorizes writes. AirLift adapter, paired session,",
            "      target authorization and reversible restore receipts require independent device tests."
        ].joined(separator: "\n")
    }
}
