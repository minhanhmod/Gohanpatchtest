import SwiftUI
import Foundation
import CryptoKit
import UIKit
import UniformTypeIdentifiers

private struct GooPatch: Codable, Identifiable, Hashable {
    let id: String
    let game: String
    let feature: String
    let version: String
    let sha256: String
    let size: Int
    let downloadPath: String
    let enabled: Bool
    let sortOrder: Int
    let packageFormat: String
    let description: String
}
private struct GooResponse: Decodable { let patches: [GooPatch] }
// Every field is optional so a partially updated Admin server does not
// prevent the iPhone from applying all other available content updates.
private struct GooConfig: Codable {
    let title: String?
    let kicker: String?
    let subtitle: String?
    let notice: String?
    let footer: String?
    let accentHex: String?
    let freeFireName: String?
    let freeFireMaxName: String?
    let applyLabel: String?
    let restoreLabel: String?
    let supportUrl: String?
    let sectionLabel: String?
    let themeLabel: String?
    let emptyTitle: String?
    let emptySubtitle: String?
    // Additional editable text; absent on older Admin deployments.
    let navigationTitle: String?
    let heroTagline: String?
    let syncTitle: String?
    let settingsTitle: String?
    let serverLabel: String?
    let syncButtonLabel: String?
}
private struct GooPlan: Codable {
    struct Rule: Codable {
        let relativePath: String
        let replacementData: Data
    }
    let format: String
    let packageId: String
    let name: String
    let game: String
    let rules: [Rule]
}
private enum GooError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let message) = self { return message }
        return nil
    }
}
enum GooPalette {
    static let all: [(String, String)] = [
        ("Đỏ", "#FF4757"),("Đỏ đậm", "#CD354C"),("Cam", "#F97342"),("Hổ phách", "#EFA53E"),
        ("Vàng", "#FFD45B"),("Chanh", "#C8DB57"),("Lục", "#69D688"),("Ngọc", "#2CC999"),
        ("Xanh biển", "#2BCBB3"),("Cyan", "#34CBDC"),("Lam", "#4CA6FF"),("Xanh trời", "#71BCFF"),
        ("Dương", "#458CF8"),("Cobalt", "#576AF0"),("Indigo", "#7770EF"),("Tím", "#9D70E8"),
        ("Oải hương", "#C196F6"),("Hồng tím", "#D27BD7"),("Hồng", "#F479B7"),("San hô", "#FF8A83"),
        ("Đồng", "#CE9B69"),("Bạc", "#A7B8CF"),("Trắng", "#F1F5FC"),("Xám", "#8795AA")
    ]
}
private extension Color {
    init(gooHex hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let n = UInt64(raw, radix: 16) ?? 0xff4757
        self.init(red: Double((n >> 16) & 255) / 255,
                  green: Double((n >> 8) & 255) / 255,
                  blue: Double(n & 255) / 255)
    }
}
private struct GooGridBackground: View {
    let tint: Color
    var body: some View {
        ZStack {
            Color(red: 0.042, green: 0.051, blue: 0.075)
            RadialGradient(colors: [tint.opacity(0.25), .clear], center: .topTrailing,
                           startRadius: 10, endRadius: 500)
            Canvas { context, size in
                var path = Path()
                let gap: CGFloat = 30
                for x in stride(from: CGFloat(0), through: size.width + gap, by: gap) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: CGFloat(0), through: size.height + gap, by: gap) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(tint.opacity(0.12)), lineWidth: 0.7)
            }
        }.ignoresSafeArea()
    }
}

private enum GooCache {
    static func path(_ name: String) throws -> URL {
        let app = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = app.appendingPathComponent("GooHanRemote", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
    static func loadCatalog() -> [GooPatch] {
        guard let url = try? path("catalog.json"), let d = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([GooPatch].self, from: d)) ?? []
    }
    static func saveCatalog(_ items: [GooPatch]) {
        guard let url = try? path("catalog.json"), let d = try? JSONEncoder().encode(items) else { return }
        try? d.write(to: url, options: .atomic)
    }
    static func loadConfig() -> GooConfig? {
        guard let url = try? path("config.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(GooConfig.self, from: data)
    }
    static func saveConfig(_ config: GooConfig) {
        guard let url = try? path("config.json"),
              let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: url, options: .atomic)
    }
    static func readPlan(_ id: String) -> GooPlan? {
        guard let url = try? path("plan_" + id + ".json"), let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(GooPlan.self, from: data)
    }
    static func savePlan(_ data: Data, id: String) throws {
        try data.write(to: path("plan_" + id + ".json"), options: .atomic)
    }
    static func hasReceipt(for patch: GooPatch) -> Bool {
        guard let plan = readPlan(patch.id), let id = UUID(uuidString: plan.packageId) else { return false }
        return DevicePatchService.latestReceipt(projectID: id) != nil
    }
}

struct ContentView: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @EnvironmentObject private var appState: AppState
    // The endpoint remains connected but is not exposed in the user settings UI.
    // This URL is public configuration, NOT a password or secret.
    private let serverURL = "https://gohanpatch-adminpatch.zcloudviet.xyz"
    @AppStorage("GooHanThemeHex") private var themeHex = "#FF4757"
    @AppStorage("GHPatchEnginePreference") private var enginePreference = GHEnginePreference.automatic.rawValue
    @AppStorage("GHLocalDevUserConfirmed") private var localDevUserConfirmed = false
    @AppStorage("GHFinalTestBeta5Tunnel") private var beta5TunnelObserved = false
    @AppStorage("GHFinalTestBeta5Pairing") private var beta5PairingObserved = false
    @AppStorage("GHFinalTestBeta5Patch") private var beta5PatchObserved = false
    @StateObject private var nativeFFITest = GHNativeFFIReadiness()
    @StateObject private var pairingVault = GHPairingVault()
    @StateObject private var pairingSession = GHNativePairingSession()
    @StateObject private var ownSandboxTransaction = GHOwnSandboxTransactionReadiness()
    @State private var pairingFileImporter = false
    @StateObject private var localDevProbe = GHLocalDevProbe()
    @State private var game = "free_fire"
    @State private var catalog: [GooPatch] = GooCache.loadCatalog()
    @State private var title = "GooHan Patch"
    @State private var kicker = "GOOHAN • PATCH MANAGER"
    @State private var subtitle = "Admin-managed Patch Library"
    @State private var notice = "Tự động áp dụng khi thiết bị có quyền truy cập phù hợp."
    @State private var footer = "Chỉ báo thành công khi tác vụ ghi/khôi phục trả về kết quả hợp lệ."
    @State private var navigationTitle = "GOOHAN PATCH"
    @State private var heroTagline = "ONE-TOGGLE PATCH • BACKUP & RESTORE"
    @State private var syncTitle = "ĐỒNG BỘ TỪ ADMIN"
    @State private var sectionLabel = "THƯ VIỆN PATCH"
    @State private var themeLabel = "24 màu giao diện"
    @State private var emptyTitle = "Chưa có gói Patch"
    @State private var emptySubtitle = "Kiểm tra Admin và nhấn đồng bộ."
    @State private var applyLabel = "Bật Patch"
    @State private var restoreLabel = "Tắt & Khôi phục"
    @State private var supportUrl = ""
    @State private var settingsTitle = "GooHan • Cài đặt"
    @State private var serverLabel = "Địa chỉ máy chủ HTTPS"
    @State private var syncButtonLabel = "Đồng bộ ngay"
    @State private var ffName = "Free Fire"
    @State private var maxName = "Free Fire MAX"
    @State private var busyId: String?
    @State private var syncing = false
    @State private var message = "Đang chờ đồng bộ"
    @State private var showSettings = false
    @State private var redrawReceipt = 0
    @State private var reconciling = false
    @State private var lastPatchStage = "Chưa có thao tác"
    @Environment(\.scenePhase) private var scenePhase

    private var color: Color { Color(gooHex: themeHex) }
    private var visible: [GooPatch] {
        catalog.filter { $0.game == game && ($0.enabled || GooCache.hasReceipt(for: $0)) }
            .sorted { $0.sortOrder == $1.sortOrder ? $0.feature < $1.feature : $0.sortOrder < $1.sortOrder }
    }
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    gamePicker
                    infoCard
                    HStack {
                        Label(sectionLabel, systemImage: "square.stack.3d.up")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        Spacer()
                        Text("\(visible.count) gói").foregroundColor(.white.opacity(0.55))
                    }
                    .foregroundColor(color)
                    if visible.isEmpty {
                        card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(emptyTitle).font(.headline)
                                Text(emptySubtitle)
                                    .font(.footnote).foregroundColor(.white.opacity(0.56))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    ForEach(visible) { patch in patchCard(patch) }
                    card {
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: "info.circle.fill").foregroundColor(color)
                            Text(message).font(.footnote).foregroundColor(.white.opacity(0.8))
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(footer)
                        .font(.caption2).foregroundColor(.white.opacity(0.44))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center).padding(.vertical, 14)
                }.padding(.horizontal, 17).padding(.top, 18).padding(.bottom, 25)
            }
            .background(GooGridBackground(tint: color))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Group {
                        if navigationTitle == "GOOHAN PATCH" {
                            HStack(spacing: 5) {
                                Text("GOOHAN").fontWeight(.black).foregroundColor(color)
                                Text("PATCH").fontWeight(.medium)
                            }
                        } else {
                            Text(navigationTitle).fontWeight(.black).foregroundColor(color)
                                .lineLimit(1).minimumScaleFactor(0.65)
                        }
                    }.font(.system(size: 15, design: .rounded))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3").foregroundColor(color)
                    }.accessibilityLabel("Cài đặt và 24 màu")
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { settingsView }
        .task {
            if let saved = GooCache.loadConfig() { applyConfig(saved) }
            await sync()
            await reconcileExternalRestores()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await reconcileExternalRestores() }
            }
        }
    }

    private var header: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(kicker)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.5).foregroundColor(color)
                    Spacer()
                    Image(systemName: "shield.lefthalf.filled").foregroundColor(color)
                }
                Text(title).font(.system(size: 33, weight: .black, design: .rounded)).lineLimit(2)
                Text(subtitle).font(.subheadline).foregroundColor(.white.opacity(0.62))
                Text(heroTagline)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.4).foregroundColor(color)
            }
        }
    }
    private var gamePicker: some View {
        HStack(spacing: 10) {
            gameButton("free_fire", ffName)
            gameButton("free_fire_max", maxName)
        }
    }
    private func gameButton(_ key: String, _ name: String) -> some View {
        Button { game = key } label: {
            Text(name).font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(game == key ? color.opacity(0.23) : Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(game == key ? color : .white.opacity(0.08)))
                .foregroundColor(.white)
        }.buttonStyle(.plain)
    }
    private var infoCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "cloud.fill").foregroundColor(color)
                    Text(syncTitle)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Spacer()
                    if syncing { ProgressView().tint(color) }
                    else {
                        Button { Task { await sync() } } label: {
                            Image(systemName: "arrow.clockwise").foregroundColor(color)
                        }.disabled(busyId != nil)
                    }
                }
                Text(notice).font(.footnote).foregroundColor(.white.opacity(0.62))
            }
        }
    }
    private func patchCard(_ patch: GooPatch) -> some View {
        let active = GooCache.hasReceipt(for: patch)
        return card {
            HStack(spacing: 13) {
                Image(systemName: active ? "checkmark.shield.fill" : "bolt.shield.fill")
                    .font(.system(size: 24, weight: .medium)).foregroundColor(color)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 5) {
                    Text(patch.feature).font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("v\(patch.version)  ·  \(active ? "Đang bật" : "Đã tắt")")
                        .font(.caption).foregroundColor(.white.opacity(0.56))
                    if !patch.description.isEmpty {
                        Text(patch.description).font(.caption2)
                            .foregroundColor(.white.opacity(0.46)).lineLimit(2)
                    }
                    Text(active ? restoreLabel : applyLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(color.opacity(0.8))
                }
                Spacer(minLength: 3)
                if busyId == patch.id { ProgressView().tint(color) }
                else {
                    Toggle("", isOn: Binding(
                        get: { _ = redrawReceipt; return GooCache.hasReceipt(for: patch) },
                        set: { newValue in Task { await toggle(patch, on: newValue) } }
                    ))
                    .labelsHidden().tint(color).disabled(busyId != nil || reconciling)
                    .accessibilityLabel(active ? restoreLabel : applyLabel)
                }
            }
        }
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().padding(17).background(Color(red: 0.093, green: 0.103, blue: 0.13).opacity(0.96),
                                         in: RoundedRectangle(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white.opacity(0.085), lineWidth: 1))
    }
    // Keep the settings root deliberately small. Under Xcode 16.4 with Release
    // whole-module optimization a single ~90-child SwiftUI ViewBuilder caused
    // "unable to type-check this expression in reasonable time" (line 361).
    // Splitting the ViewBuilder into independent, typed sections lets Swift
    // compile each expression without changing the settings behavior.
    private var settingsView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsEngineSection
                    Divider()
                    settingsLocalDevSection
                    settingsNativeFFISection
                    settingsTransactionSection
                    settingsBeta5ComparisonSection
                    settingsFinalGateSection
                    settingsDiagnosticsSection
                    settingsThemeSection
                    settingsActionsSection
                }
                .padding(20)
            }
            .navigationTitle(settingsTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { showSettings = false }
                }
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $pairingFileImporter,
                      allowedContentTypes: [.data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                pairingVault.importFromFiles(url)
            }
        }
    }

    @ViewBuilder
    private var settingsEngineSection: some View {
        Text("Cơ chế áp dụng Patch")
            .font(.headline)
        Picker("Engine", selection: $enginePreference) {
            Text("Tự động (GooHan cũ)").tag(GHEnginePreference.automatic.rawValue)
            Text("GooHan cũ").tag(GHEnginePreference.legacy.rawValue)
            Text("AirLift – chưa tích hợp").tag(GHEnginePreference.airlift.rawValue)
                .disabled(!GHInstalledPatchEngine.airLiftReady)
        }
        .pickerStyle(.menu)
        Text("Đã tích hợp thư viện native và thử pairing/session; chưa có AirLift Patch Driver với sao lưu, xác minh và khôi phục. GooHan không ghi Patch trên iOS 27 trong bản thử.")
            .font(.footnote)
            .foregroundColor(.secondary)
        Text(GHInstalledPatchEngine.deviceSummary())
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var settingsLocalDevSection: some View {
        Text("iOS 27 • LocalDevVPN — Final Test v3.3")
            .font(.headline)
        Toggle("Tôi đã tự bật LocalDevVPN trên iPhone", isOn: $localDevUserConfirmed)
            .font(.footnote)
        Button(localDevProbe.isChecking ? "Đang kiểm tra TCP cục bộ…" : "Kiểm tra kết nối cục bộ (chỉ đọc)") {
            localDevProbe.check()
        }
        .disabled(localDevProbe.isChecking)
        .buttonStyle(.bordered)
        Text("Mã kiểm tra: " + localDevProbe.statusCode)
            .font(.caption.monospaced())
            .foregroundColor(.secondary)
        Text(localDevProbe.resultText)
            .font(.caption2)
            .foregroundColor(.secondary)
        Text(localDevProbe.routeSummary)
            .font(.caption2.monospaced())
            .foregroundColor(.secondary)
        Text("Kiểm tra gần nhất: " + localDevProbe.completedAt)
            .font(.caption2)
            .foregroundColor(.secondary)
        Text("Đây là xác nhận thủ công, không phải kiểm tra kết nối hay bằng chứng quyền ghi. GooHan không thể tự bật VPN của ứng dụng khác.")
            .font(.caption2)
            .foregroundColor(.secondary)
        Link("Mở trang LocalDevVPN trên App Store",
             destination: URL(string: "https://apps.apple.com/app/id6755608044")!)
            .font(.caption)
        Text(localDevReadinessReport)
            .font(.caption2)
            .foregroundColor(.secondary)
            .textSelection(.enabled)
        Link("Tạo File Pair bằng idevice_pair (dành cho 3105 Beta 5)",
             destination: URL(string: "https://github.com/jkcoxson/idevice_pair")!)
            .font(.caption)
        Text("File Pair là dữ liệu ghép đôi nhạy cảm. Không đăng tải lên GitHub, ChatGPT hoặc máy chủ Admin. GooHan chưa có AirLift Patch Driver để ghi bằng file đó.")
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var settingsNativeFFISection: some View {
        Text("iOS 27 • AirLift Session + Container Test v4.4")
            .font(.headline)
        Text("FFI đã liên kết. v4.4 yêu cầu mã native rc=0 và sự kiện syslog, sau đó kiểm tra đường dẫn container của chính GooHan (chỉ đọc). Không ghi Patch.")
            .font(.caption2)
            .foregroundColor(.secondary)
        Button("Kiểm tra thư viện native") {
            nativeFFITest.runLibrarySmokeTest()
        }
        .buttonStyle(.bordered)
        Text("FFI: " + nativeFFITest.statusCode)
            .font(.caption.monospaced())
            .textSelection(.enabled)
        Text("Pairing: " + pairingVault.statusCode)
            .font(.caption.monospaced())
            .textSelection(.enabled)
        Button(pairingSession.pairingInProgress ? "Đang chờ ghép đôi native…" : "Bắt đầu ghép đôi trực tiếp (AirLift)") {
            pairingSession.start(vault: pairingVault)
        }
        .disabled(pairingSession.pairingInProgress || pairingSession.sessionInProgress || pairingSession.ownContainerInProgress)
        .buttonStyle(.borderedProminent)
        Text("Native pairing: " + pairingSession.pairingCode)
            .font(.caption.monospaced())
            .textSelection(.enabled)
        Text("Bonjour: " + pairingSession.bonjourCode)
            .font(.caption.monospaced())
        if !pairingSession.presentedPIN.isEmpty {
            Text("PIN (chỉ hiện trên iPhone): " + pairingSession.presentedPIN)
                .font(.headline.monospaced())
        }
        Text("Khi bắt đầu, mở Cài đặt iOS → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển để hoàn tất pairing. iOS có thể tạm dừng ứng dụng nền; nếu kẹt, đóng/mở lại GooHan.")
            .font(.caption2)
            .foregroundColor(.secondary)
        Button(pairingSession.sessionInProgress ? "Đang truy vấn chỉ đọc…" : "Kiểm tra phiên AirLift (không ghi dữ liệu)") {
            pairingSession.verifySelfReadOnly(vault: pairingVault)
        }
        .buttonStyle(.bordered)
        .disabled(pairingSession.sessionInProgress || pairingSession.pairingInProgress || !pairingVault.recordPresent)
        Text("Session: " + pairingSession.sessionCode)
            .font(.caption.monospaced())
            .textSelection(.enabled)
        Text("Native rc: " + pairingSession.nativeSessionReturnCode)
            .font(.caption2.monospaced())
        Text("Session strict pass: " + (pairingSession.sessionValid(for: pairingVault) ? "YES" : "NO"))
            .font(.caption2.monospaced())
        Button(pairingSession.ownContainerInProgress ? "Đang tìm container GooHan…" : "Kiểm tra container GooHan (AirLift, chỉ đọc)") {
            pairingSession.testOwnContainerReadOnly(vault: pairingVault)
        }
        .buttonStyle(.bordered)
        .disabled(!pairingSession.sessionValid(for: pairingVault) || pairingSession.ownContainerInProgress || pairingSession.sessionInProgress || pairingSession.pairingInProgress)
        Text("Own container: " + pairingSession.ownContainerCode)
            .font(.caption.monospaced())
            .textSelection(.enabled)
        Text("Chỉ kiểm tra bundle ID của chính GooHan và so khớp với sandbox hiện tại; không đọc nội dung file hoặc container ứng dụng khác. Native có thể trả lỗi nếu dịch vụ không cho phép tra cứu.")
            .font(.caption2)
            .foregroundColor(.secondary)
        Text("Kết quả phiên không chứng minh quyền ghi Patch. GooHan chỉ đếm tín hiệu luồng hệ thống, không lưu nội dung; lỗi có thể do pairing, LocalDev hoặc dịch vụ thiết bị.")
            .font(.caption2)
            .foregroundColor(.secondary)
        Button("Nhập pairing từ Files (lưu riêng trên iPhone)") {
            pairingFileImporter = true
        }
        .buttonStyle(.bordered)
        if pairingVault.recordPresent {
            Button("Xóa pairing đã nhập", role: .destructive) {
                pairingVault.delete()
            }
        }
        Text("File Pair là thông tin xác thực nhạy cảm. Không gửi cho người khác. Bản v4.4 không dùng pairing để ghi Patch vào ứng dụng khác.")
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var settingsTransactionSection: some View {
        Text("iOS 27 • Giao dịch thử nghiệm v4.5")
            .font(.headline)
        Text("Sau khi kiểm chứng phiên và container GooHan, chạy thử Backup → Write → Verify SHA-256 → Restore CHỈ trong Application Support của GooHan. Đây là ghi bằng Foundation, KHÔNG phải engine ghi AirLift.")
            .font(.caption2)
            .foregroundColor(.secondary)
        Button(ownSandboxTransaction.isRunning ? "Đang thử giao dịch…" : "1. Backup → Write → Verify → Restore") {
            ownSandboxTransaction.run()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!v45SandboxPreconditionsReady || ownSandboxTransaction.isRunning)
        Button("2. Giả lập lỗi sau Backup (kiểm thử rollback)") {
            ownSandboxTransaction.run(fault: .afterVerifiedBackup)
        }
        .buttonStyle(.bordered)
        .disabled(!v45SandboxPreconditionsReady || ownSandboxTransaction.isRunning)
        Button("3. Giả lập lỗi sau Write (kiểm thử rollback)") {
            ownSandboxTransaction.run(fault: .afterReplacementWrite)
        }
        .buttonStyle(.bordered)
        .disabled(!v45SandboxPreconditionsReady || ownSandboxTransaction.isRunning)
        Text("V4.5: " + ownSandboxTransaction.resultCode)
            .font(.caption.monospaced())
            .foregroundColor(.orange)
            .textSelection(.enabled)
        Text(ownSandboxTransaction.safeReport)
            .font(.caption2.monospaced())
            .foregroundColor(.secondary)
            .textSelection(.enabled)
        Text("Nếu nút bị khóa, chạy lại Session → Own Container ở phía trên. Thành công v4.5 KHÔNG chứng minh có quyền ghi container ứng dụng khác; AIRLIFT_PATCH_DRIVER_MISSING vẫn giữ nguyên.")
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var settingsBeta5ComparisonSection: some View {
        Text("Đối chiếu với 3105 Beta 5 (cùng iPhone)")
            .font(.headline)
        Toggle("3105: tunnel báo Hoạt động", isOn: $beta5TunnelObserved)
            .font(.footnote)
        Toggle("3105: pairing báo Sẵn sàng", isOn: $beta5PairingObserved)
            .font(.footnote)
        Toggle("3105: đã áp dụng cùng gói Patch thành công", isOn: $beta5PatchObserved)
            .font(.footnote)
        Text("Ba mục này do người thử nghiệm tự xác nhận từ 3105 Beta 5. Chúng KHÔNG cho thấy GooHan đã xác thực pairing hay ghi thành công.")
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var settingsFinalGateSection: some View {
        Text("Kết luận điều kiện tiền kiểm")
            .font(.headline)
        Text("Mã v4.4: " + v44ReadinessGate)
            .font(.caption.monospaced())
            .foregroundColor(.orange)
        Text("Mã v3.3 (tham chiếu TCP): " + finalGate.resultCode)
            .font(.caption2.monospaced())
            .foregroundColor(.secondary)
        Text("Đã bổ sung rc0 + event và phép thử tra cứu chính container. Chưa có AirLift Patch Driver hoặc Restore được xác minh. Không ghi trên iOS 27.")
            .font(.caption2)
            .foregroundColor(.secondary)
        Button("Sao chép báo cáo v4.5") {
            UIPasteboard.general.string = engineDiagnosticsReport()
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    private var v45SandboxPreconditionsReady: Bool {
        pairingSession.sessionValid(for: pairingVault)
            && pairingSession.ownContainerCode == "NATIVE_OWN_CONTAINER_READ_ONLY_OK"
    }

    /// Native read-only checks take precedence over older manual/TCP
    /// checkboxes in the v4.4 release-readiness summary. Still NEVER enable Patch.
    private var v44ReadinessGate: String {
        guard pairingSession.sessionValid(for: pairingVault) else {
            return "V44_SESSION_STRICT_UNVERIFIED"
        }
        guard pairingSession.ownContainerCode == "NATIVE_OWN_CONTAINER_READ_ONLY_OK" else {
            return "V44_OWN_CONTAINER_READ_NOT_VERIFIED"
        }
        return "V44_READ_ONLY_PREREQUISITES_OK_PATCH_DRIVER_MISSING"
    }

    private var finalGate: GHFinalTestGate {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return GHFinalTestGate(
            major: os.majorVersion,
            minor: os.minorVersion,
            build: AppInfo.osBuild,
            probeCode: localDevProbe.statusCode,
            userConfirmedLocalDev: localDevUserConfirmed,
            beta5TunnelObserved: beta5TunnelObserved,
            beta5PairingObserved: beta5PairingObserved,
            beta5PatchObserved: beta5PatchObserved,
            nativeAirLiftRegistered: GHInstalledPatchEngine.airLiftReady
        )
    }

    private var localDevReadinessReport: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let readiness = GHLocalDevReadiness(
            major: os.majorVersion,
            minor: os.minorVersion,
            build: AppInfo.osBuild,
            userConfirmedLocalDev: localDevUserConfirmed,
            nativeAirLiftRegistered: GHInstalledPatchEngine.airLiftReady
        )
        return readiness.report
    }

    @ViewBuilder
    private var settingsDiagnosticsSection: some View {
        Button("Sao chép báo cáo chẩn đoán engine") {
            UIPasteboard.general.string = engineDiagnosticsReport()
        }
        .buttonStyle(.bordered)
    }

    private func engineDiagnosticsReport() -> String {
        // Do not include paths, device identifiers or License keys.
        // Session status does not establish kernel R/W or write permission.
        let permissionNote: String
        if KernelExploit.requiresSandboxEscape {
            permissionNote = KernelExploit.hasSandboxAccess()
                ? "active" : "inactive-or-unverified"
        } else {
            permissionNote = "not-applicable-to-iOS-17-18"
        }
        return GHInstalledPatchEngine.diagnosticsText()
            + "\nLocalDev TCP probe: " + localDevProbe.statusCode
            + "\nLocalDev TCP routes: " + localDevProbe.routeSummary
            + "\nLocalDev last tested at: " + localDevProbe.completedAt
            + "\nNative AirLift FFI link-only test: " + nativeFFITest.statusCode
            + "\nPairing local vault: " + pairingVault.statusCode
            + "\n" + pairingSession.safeReport(for: pairingVault)
            + "\n" + ownSandboxTransaction.safeReport
            + "\nV4.4 readiness gate: " + v44ReadinessGate
            + "\nV4.5 patch release gate: AIRLIFT_PATCH_DRIVER_MISSING"
            + "\nV3.3 legacy TCP comparison only (not v4.4 blocker):\n" + finalGate.report
            + "\n" + localDevReadinessReport
            + "\nTrạng thái quyền truy cập (phiên): " + appState.exploitStatus.displayText
            + "\nSandbox probe: " + permissionNote
            + "\nGiai đoạn cuối: " + lastPatchStage
    }

    @ViewBuilder
    private var settingsThemeSection: some View {
        Text(themeLabel)
            .font(.headline)
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
            spacing: 16
        ) {
            ForEach(0..<GooPalette.all.count, id: \.self) { index in
                let item = GooPalette.all[index]
                Button { themeHex = item.1 } label: {
                    Circle()
                        .fill(Color(gooHex: item.1))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().stroke(.white, lineWidth: themeHex == item.1 ? 2.5 : 0)
                        )
                }
                .accessibilityLabel(item.0)
            }
        }
    }

    @ViewBuilder
    private var settingsActionsSection: some View {
        if let link = URL(string: supportUrl), link.scheme == "https" {
            Link("Hỗ trợ", destination: link)
                .font(.subheadline)
                .foregroundColor(color)
        }
        Text("Bản này chỉ có thể thao tác với dữ liệu khi iOS thực sự cấp quyền. Không có thao tác chọn thư mục; nếu không đủ quyền, công tắc sẽ giữ trạng thái OFF và hiển thị lỗi.")
            .font(.footnote)
            .foregroundColor(.secondary)
        if let expiry = licenseManager.expirationDate {
            Text("License có hiệu lực đến: \(expiry.formatted(date: .abbreviated, time: .shortened))")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        Button("Đăng xuất License") {
            licenseManager.deactivate()
        }
        .foregroundColor(.orange)
        Button(syncButtonLabel) {
            showSettings = false
            Task { await sync() }
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }
    private func baseURL() throws -> URL {
        guard let url = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", url.host != nil else {
            throw GooError.message("Hãy nhập một URL HTTPS hợp lệ")
        }
        return url
    }
    private func getData(_ url: URL) async throws -> Data {
        try await licenseManager.authenticatedData(from: url)
    }
    private func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    private func applyConfig(_ cfg: GooConfig) {
        title = cfg.title ?? title
        kicker = cfg.kicker ?? kicker
        subtitle = cfg.subtitle ?? subtitle
        notice = cfg.notice ?? notice
        footer = cfg.footer ?? footer
        navigationTitle = cfg.navigationTitle ?? navigationTitle
        heroTagline = cfg.heroTagline ?? heroTagline
        syncTitle = cfg.syncTitle ?? syncTitle
        sectionLabel = cfg.sectionLabel ?? sectionLabel
        themeLabel = cfg.themeLabel ?? themeLabel
        emptyTitle = cfg.emptyTitle ?? emptyTitle
        emptySubtitle = cfg.emptySubtitle ?? emptySubtitle
        applyLabel = cfg.applyLabel ?? applyLabel
        restoreLabel = cfg.restoreLabel ?? restoreLabel
        supportUrl = cfg.supportUrl ?? supportUrl
        settingsTitle = cfg.settingsTitle ?? settingsTitle
        serverLabel = cfg.serverLabel ?? serverLabel
        syncButtonLabel = cfg.syncButtonLabel ?? syncButtonLabel
        ffName = cfg.freeFireName ?? ffName
        maxName = cfg.freeFireMaxName ?? maxName
        if UserDefaults.standard.object(forKey: "GooHanThemeHex") == nil,
           let hex = cfg.accentHex,
           hex.range(of: "^#[A-Fa-f0-9]{6}$", options: .regularExpression) != nil {
            themeHex = hex
        }
    }
    private func sync() async {
        if syncing { return }
        syncing = true
        defer { syncing = false }
        do {
            let base = try baseURL()
            // A configuration read error must be visible, not silently ignored.
            // Patches still sync even when the branding endpoint is unavailable.
            var configWarning: String?
            do {
                let payload = try await getData(base.appendingPathComponent("api/config"))
                let cfg = try jsonDecoder().decode(GooConfig.self, from: payload)
                applyConfig(cfg)
                GooCache.saveConfig(cfg)
            } catch {
                configWarning = "Không tải được nội dung từ Admin: \(error.localizedDescription)"
            }
            var incoming: [GooPatch] = []
            for key in ["free_fire", "free_fire_max"] {
                var components = URLComponents(url: base.appendingPathComponent("api/patches"), resolvingAgainstBaseURL: false)!
                components.queryItems = [URLQueryItem(name: "game", value: key)]
                guard let url = components.url else { continue }
                let response = try jsonDecoder().decode(GooResponse.self, from: await getData(url))
                incoming += response.patches.filter { $0.game == key }
            }
            let old = GooCache.loadCatalog()
            let activeMissing = old.filter { oldPatch in
                !incoming.contains(where: { $0.id == oldPatch.id }) && GooCache.hasReceipt(for: oldPatch)
            }
            catalog = incoming + activeMissing
            GooCache.saveCatalog(catalog)
            message = "Đã đồng bộ \(incoming.count) gói từ Admin." +
                      (configWarning.map { " \($0)" } ?? "")
        } catch {
            message = "Lỗi đồng bộ: \(error.localizedDescription). Các gói đang bật vẫn được giữ để khôi phục."
        }
    }
    private func project(from plan: GooPlan, for patch: GooPatch) throws -> PatchProject {
        guard plan.format == "3105-project-v1", plan.game == patch.game,
              let uuid = UUID(uuidString: plan.packageId),
              (1...100).contains(plan.rules.count) else {
            throw GooError.message("Kế hoạch .3105 không hợp lệ")
        }
        let bundleID: String = patch.game == "free_fire" ? "com.dts.freefireth" : "com.dts.freefiremax"
        var seen = Set<String>()
        let rules: [PatchRule] = try plan.rules.map { rule in
            let safe = try PatchPathValidator.canonicalRelativePath(rule.relativePath)
            guard seen.insert(safe).inserted else { throw GooError.message("Gói có đường dẫn trùng") }
            return PatchRule(bundleID: bundleID, relativePath: safe,
                             replacementFilename: (safe as NSString).lastPathComponent,
                             replacementData: rule.replacementData)
        }
        return PatchProject(id: uuid, name: plan.name, bundleIdentifiers: [bundleID], rules: rules)
    }
    // If another process already restored every destination to its original
    // fingerprint, close only the stale receipt and refresh the visible switch.
    // Divergent/unknown contents are never overwritten by this reconciliation.
    private func reconcileExternalRestores() async {
        guard busyId == nil && !reconciling else { return }
        reconciling = true
        defer { reconciling = false; redrawReceipt += 1 }
        let snapshot = catalog
        let count = await Task.detached(priority: .utility) { () -> Int in
            var closed = 0
            for patch in snapshot {
                guard let plan = GooCache.readPlan(patch.id),
                      let id = UUID(uuidString: plan.packageId),
                      let receipt = DevicePatchService.latestReceipt(projectID: id) else {
                    continue
                }
                if (try? DevicePatchService.reconcileAlreadyRestored(receipt: receipt)) == true {
                    closed += 1
                }
            }
            return closed
        }.value
        if count > 0 {
            message = "Đã phát hiện \(count) gói được khôi phục từ bên ngoài. Công tắc đã cập nhật về OFF; có thể bật lại."
        }
    }

    private func toggle(_ patch: GooPatch, on: Bool) async {
        guard busyId == nil && !reconciling else { return }
        busyId = patch.id
        defer { busyId = nil; redrawReceipt += 1 }
        do {
            if on {
                lastPatchStage = "Xác thực License"
                try await licenseManager.ensureAuthorized()
                // Fail explicitly on unverified OS builds. Do not run a kernel exploit
                // simply because the version string resembles a supported beta.
                lastPatchStage = "Kiểm tra hỗ trợ phiên bản iOS"
                let os = ProcessInfo.processInfo.operatingSystemVersion
                let preference = GHEnginePreference(rawValue: enginePreference) ?? .automatic
                let legacyVerified = ExploitSupportPolicy.isSupported(
                    major: os.majorVersion, minor: os.minorVersion,
                    patch: os.patchVersion, build: AppInfo.osBuild
                )
                // On an unverified build never run the legacy engine. Only a
                // separately implemented and registered native provider may be
                // considered; simple "supported = true" is not sufficient.
                let canUseNativeRoute = GHInstalledPatchEngine.airLiftReady && preference != .legacy
                if !legacyVerified && !canUseNativeRoute {
                    throw GooError.message("iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)): engine GooHan cũ chưa được xác minh và AirLift chưa được tích hợp. File Pair của 3105 Beta 5 không tự cấp quyền cho GooHan. Không áp dụng Patch để tránh ghi dữ liệu sai.")
                }
                guard !GooCache.hasReceipt(for: patch) else { return }
                lastPatchStage = "Kiểm tra thông tin gói Patch"
                guard patch.enabled, patch.packageFormat == "3105" else {
                    throw GooError.message("Chỉ hỗ trợ gói .3105 đang được Admin xuất bản")
                }
                guard patch.id.count == 32, patch.id.allSatisfy({ $0.isHexDigit }),
                      patch.downloadPath == "/downloads/" + patch.id,
                      patch.size > 0 && patch.size <= 75 * 1024 * 1024 else {
                    throw GooError.message("Thông tin gói Patch không hợp lệ")
                }
                let root = try baseURL()
                let remote = root.appendingPathComponent("downloads").appendingPathComponent(patch.id)
                lastPatchStage = "Tải gói từ Admin"
                let data = try await getData(remote)
                lastPatchStage = "Kiểm tra SHA-256 và kích thước"
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard data.count == patch.size, hash == patch.sha256.lowercased() else {
                    throw GooError.message("Không khớp SHA-256 hoặc kích thước file")
                }
                lastPatchStage = "Đọc và kiểm tra kế hoạch Patch"
                let plan = try jsonDecoder().decode(GooPlan.self, from: data)
                let project = try project(from: plan, for: patch)
                // Persist before applying so recovery stays reachable after a network outage.
                try GooCache.savePlan(data, id: patch.id)
                lastPatchStage = "Áp dụng Patch qua engine"
                let result = try await GHInstalledPatchEngine.apply(
                    project: project, preference: preference
                )
                lastPatchStage = "Kiểm tra biên nhận khôi phục"
                guard GooCache.hasReceipt(for: patch) else {
                    throw GooError.message("Không thấy biên nhận Patch; không thể xác nhận thành công")
                }
                lastPatchStage = "Áp dụng thành công"
                message = "Đã áp dụng \(patch.feature) qua \(result.selected.rawValue); có biên nhận khôi phục."
            } else {
                lastPatchStage = "Khôi phục Patch bằng biên nhận cũ"
                guard let plan = GooCache.readPlan(patch.id), let id = UUID(uuidString: plan.packageId),
                      let receipt = DevicePatchService.latestReceipt(projectID: id) else {
                    throw GooError.message("Không tìm thấy biên nhận để khôi phục")
                }
                try await Task.detached(priority: .userInitiated) {
                    try DevicePatchService.restore(receipt: receipt)
                }.value
                guard DevicePatchService.latestReceipt(projectID: id) == nil else {
                    throw GooError.message("Khôi phục chưa hoàn tất; vẫn giữ trạng thái bật")
                }
                lastPatchStage = "Khôi phục thành công"
                message = "Đã tắt \(patch.feature). Tệp đã là bản gốc hoặc đã được khôi phục từ bản sao lưu."
            }
        } catch {
            message = "Không thể \(on ? "bật" : "tắt") \(patch.feature): \(error.localizedDescription)"
        }
    }
}

// Available even when a key expires. Restoring the original files never
// needs a server session, so an expired/revoked key cannot trap an active Patch.
struct GooHanRecoveryPanel: View {
    @State private var result = ""
    @State private var busy = false
    @State private var refreshID = UUID()

    private var recoverable: [GooPatch] {
        _ = refreshID
        return GooCache.loadCatalog().filter { GooCache.hasReceipt(for: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                Text("Khôi phục tệp gốc")
            }.font(.headline)
            Text("Ngay cả khi key đã hết hạn, bạn vẫn có thể khôi phục những gói đã bật trên thiết bị này.")
                .font(.caption).foregroundColor(.white.opacity(0.65))
            ForEach(recoverable) { patch in
                Button("Khôi phục \(patch.feature)") {
                    guard !busy else { return }
                    busy = true
                    Task {
                        defer { busy = false; refreshID = UUID() }
                        do {
                            guard let plan = GooCache.readPlan(patch.id),
                                  let id = UUID(uuidString: plan.packageId),
                                  let receipt = DevicePatchService.latestReceipt(projectID: id) else { return }
                            try await Task.detached(priority: .userInitiated) {
                                try DevicePatchService.restore(receipt: receipt)
                            }.value
                            result = "Đã khôi phục \(patch.feature)"
                        } catch { result = error.localizedDescription }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(busy)
            }
            if recoverable.isEmpty {
                Text("Không có bản Patch nào cần khôi phục.")
                    .font(.caption).foregroundColor(.white.opacity(0.4))
            }
            if !result.isEmpty { Text(result).font(.caption).foregroundColor(.orange) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.16), in: RoundedRectangle(cornerRadius: 22))
    }
}
