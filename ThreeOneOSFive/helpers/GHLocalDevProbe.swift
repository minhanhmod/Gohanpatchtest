import Foundation
import Network
import Combine

/// A read-only TCP route comparison for iOS 27 developer tunnels.
/// Port reachability is never treated as VPN/pairing/AirLift authentication.
/// No pairing records, credentials, package payloads, or target paths are read.
@MainActor
final class GHLocalDevProbe: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var statusCode = "NOT_TESTED"
    @Published private(set) var resultText = "Chưa chạy kiểm tra kết nối cục bộ."
    @Published private(set) var routeSummary = "Chưa có kết quả."
    @Published private(set) var completedAt = "Chưa kiểm tra"

    /// Common examples only. Real RSD endpoints can use dynamically assigned ports.
    /// In particular, a closed TCP port does not show that LocalDevVPN is disabled.
    private static let endpoints: [(host: String, port: UInt16, kind: String)] = [
        ("10.7.0.3", 49152, "RSD example"),
        ("10.7.0.1", 62078, "Lockdown example"),
        ("10.7.0.2", 62078, "Lockdown alternative"),
        ("10.7.0.3", 62078, "Lockdown alternative"),
        ("127.0.0.1", 62078, "Loopback example")
    ]

    func check() {
        guard !isChecking else { return }
        isChecking = true
        statusCode = "RUNNING"
        resultText = "Kiểm tra cổng TCP cục bộ, không đọc/ghi dữ liệu thiết bị…"
        routeSummary = "Đang thử các tuyến mẫu (cổng thực tế có thể khác)."
        Task {
            var reachable: [String] = []
            var checked = 0
            for endpoint in Self.endpoints {
                if Task.isCancelled { break }
                let opened = await Self.isTCPReachable(host: endpoint.host, port: endpoint.port)
                checked += 1
                if opened {
                    reachable.append("\(endpoint.host):\(endpoint.port) [\(endpoint.kind)]")
                }
            }
            completedAt = ISO8601DateFormatter().string(from: Date())
            if !reachable.isEmpty {
                statusCode = "LOCAL_TCP_PORT_REACHABLE_ONLY"
                resultText = "Phát hiện kết nối TCP cục bộ. KHÔNG xác minh pairing, RSD handshake, AirLift hoặc quyền ghi."
                routeSummary = "Đã thử \(checked) tuyến; TCP phản hồi: " + reachable.joined(separator: ", ")
            } else {
                statusCode = "LOCAL_TCP_PORT_NOT_DETECTED"
                resultText = "Chưa tìm thấy cổng TCP mẫu phản hồi; KHÔNG đủ cơ sở kết luận LocalDevVPN đã tắt."
                routeSummary = "Đã thử \(checked) tuyến mẫu; không phát hiện cổng mở. Endpoint RSD có thể dùng cổng động."
            }
            isChecking = false
        }
    }

    /// Never log the raw connection error (it can include device/network details).
    private static func isTCPReachable(host: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "fun.gohan.localdev.final-probe")
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: false)
                return
            }
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let gate = GHProbeCompletionGate()
            let complete: (Bool) -> Void = { success in
                guard gate.tryFinish() else { return }
                connection.stateUpdateHandler = nil
                connection.cancel()
                continuation.resume(returning: success)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: complete(true)
                case .failed, .cancelled: complete(false)
                default: break
                }
            }
            queue.asyncAfter(deadline: .now() + .milliseconds(1300)) { complete(false) }
            connection.start(queue: queue)
        }
    }
}

private final class GHProbeCompletionGate {
    private let lock = NSLock()
    private var finished = false
    func tryFinish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if finished { return false }
        finished = true
        return true
    }
}
