import Foundation
@main struct FinalGateVerify {
    static func main() {
        func gate(_ major: Int = 27, _ minor: Int = 0, _ probe: String = "LOCAL_TCP_PORT_REACHABLE_ONLY",
                  confirmed: Bool = true, tunnel: Bool = true, pairing: Bool = true,
                  applied: Bool = true, native: Bool = false) -> GHFinalTestGate {
            GHFinalTestGate(major: major, minor: minor, build: "24A437",
                probeCode: probe, userConfirmedLocalDev: confirmed,
                beta5TunnelObserved: tunnel, beta5PairingObserved: pairing,
                beta5PatchObserved: applied, nativeAirLiftRegistered: native)
        }
        precondition(gate(26).resultCode == "OUT_OF_TEST_SCOPE")
        precondition(gate(27, 3).resultCode == "OUT_OF_TEST_SCOPE")
        precondition(gate(27, 0, "NOT_TESTED").resultCode == "READ_ONLY_TCP_TEST_REQUIRED")
        precondition(gate(confirmed: false).resultCode == "LOCALDEV_NOT_USER_CONFIRMED")
        precondition(gate(tunnel: false).resultCode == "BETA5_TUNNEL_NOT_OBSERVED")
        precondition(gate(pairing: false).resultCode == "BETA5_PAIRING_NOT_OBSERVED")
        precondition(gate(applied: false).resultCode == "BETA5_PATCH_NOT_OBSERVED")
        precondition(gate().resultCode == "NATIVE_AIRLIFT_IMPLEMENTATION_REQUIRED")
        precondition(gate(native: true).resultCode == "NATIVE_DRIVER_REQUIRES_AUTH_AND_RESTORE_TEST")
        precondition(gate(27, 2).resultCode == "IOS27_2_BUILD_OUTSIDE_BETA_1_2_SCOPE")
        let beta2 = GHFinalTestGate(major: 27, minor: 2, build: "24B5089g",
            probeCode: "LOCAL_TCP_PORT_REACHABLE_ONLY", userConfirmedLocalDev: true,
            beta5TunnelObserved: true, beta5PairingObserved: true,
            beta5PatchObserved: true, nativeAirLiftRegistered: false)
        precondition(beta2.resultCode == "NATIVE_AIRLIFT_IMPLEMENTATION_REQUIRED")
        precondition(gate().report.contains("not verified in GooHan"))
        precondition(gate(27, 0, "LOCAL_TCP_PORT_NOT_DETECTED").resultCode == "NATIVE_AIRLIFT_IMPLEMENTATION_REQUIRED")
        print("PASS: final test gate never treats a manual tunnel/pairing report as native write access")
    }
}
