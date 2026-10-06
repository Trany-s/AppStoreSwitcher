import SwiftUI
import AppKit

@main
struct AppStoreSwitcherApp: App {
    @StateObject private var store = AccountStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("App Store 账号管理", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 520, minHeight: 380)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("App Store 账号管理", systemImage: "person.crop.circle.badge.checkmark") {
            Button("打开账号管理界面") {
                openWindow(id: "main")
            }
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
