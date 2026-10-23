import Foundation

struct PatchProject { let id: UUID }
struct StubReceipt {}
enum DevicePatchService {
    static var applied: UUID?
    static var allowContainer = true
    static func preflight(project: PatchProject) throws {
        if !allowContainer { throw PatchPackageError.targetAppUnavailable("test.app") }
    }
    static func apply(project: PatchProject) throws -> StubReceipt {
        applied = project.id
        return StubReceipt()
    }
    static func latestReceipt(projectID: UUID) -> StubReceipt? {
        applied == projectID ? StubReceipt() : nil
    }
}
enum PatchPackageError: Error {
    case targetAppUnavailable(String)
}
enum AppInfo { static let osBuild = "24A000" }
enum ExploitSupportPolicy {
    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        major < 27
    }
}

@main
struct DualEngineWiringTests {
    @MainActor static func main() async throws {
        let project = PatchProject(id: UUID())
        let success = try await GHInstalledPatchEngine.apply(project: project, preference: .automatic)
        precondition(success.selected == .legacy)
        precondition(DevicePatchService.applied == project.id)
        precondition(GHInstalledPatchEngine.airLiftReady == false)
        print("PASS: Legacy adapter applies the project and confirms receipt")
        do {
            _ = try await GHInstalledPatchEngine.apply(project: project, preference: .airlift)
            fatalError("AirLift should not be registered")
        } catch GHEngineFailure.unavailable(.airlift) {
            print("PASS: AirLift without native implementation is unavailable")
        }
        precondition(GHInstalledPatchEngine.diagnosticsText().contains("AirLift: chưa tích hợp"))
        print("PASS: Diagnostic states missing AirLift implementation")
        DevicePatchService.applied = nil
        DevicePatchService.allowContainer = false
        do {
            _ = try await GHInstalledPatchEngine.apply(project: project, preference: .automatic)
            fatalError("A missing target container must be reported as a pre-write failure")
        } catch GHEngineFailure.preflightFailed(.legacy, let msg) {
            precondition(msg.contains("container"))
            precondition(DevicePatchService.applied == nil)
            precondition(GHPatchEngineCoordinator.shared.events.last?.phase == "prewrite")
            precondition(GHPatchEngineCoordinator.shared.events.last?.detail.contains("TARGET_CONTAINER_UNRESOLVED") == true)
            print("PASS: Missing app container classified as pre-write; no patch was attempted")
        }
        DevicePatchService.allowContainer = true
    }
}
