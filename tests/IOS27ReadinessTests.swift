import Foundation
@main
struct IOS27ReadinessTests {
    static func main() {
        let rc = GHLocalDevReadiness(major: 27, minor: 0, build: "24A435", userConfirmedLocalDev: true, nativeAirLiftRegistered: false)
        precondition(rc.code == "NATIVE_AIRLIFT_MISSING")
        precondition(rc.buildNote.contains("RC"))
        precondition(rc.report.contains("GooHan chưa xác minh"))
        let release = GHLocalDevReadiness(major: 27, minor: 0, build: "24A437", userConfirmedLocalDev: false, nativeAirLiftRegistered: true)
        precondition(release.code == "LOCALDEV_NOT_USER_CONFIRMED")
        let noPermissionClaim = GHLocalDevReadiness(major: 27, minor: 1, build: "other", userConfirmedLocalDev: true, nativeAirLiftRegistered: true)
        precondition(noPermissionClaim.code == "NATIVE_PRESENT_DEVICE_VALIDATION_REQUIRED")
        let patchRisk = GHLocalDevReadiness(major: 27, minor: 2, build: "other", userConfirmedLocalDev: false, nativeAirLiftRegistered: false)
        precondition(patchRisk.buildNote.contains("beta"))
        let differentOS = GHLocalDevReadiness(major: 26, minor: 6, build: "other", userConfirmedLocalDev: true, nativeAirLiftRegistered: true)
        precondition(differentOS.code == "OUTSIDE_IOS27_SCOPE")
        print("PASS: iOS27 readiness is diagnostic-only and cannot falsely authorize writing")
    }
}
