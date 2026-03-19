import AppKit
import SwiftUI

enum AppWindowID {
    static let settings = "settings-window"
}

enum SettingsWindowLayout {
    static let width: CGFloat = 520
    static let goldenRatio: CGFloat = 1.61803398875
    static let height: CGFloat = width * goldenRatio
}

@main
struct ConfBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DeadlineStore()

    var body: some Scene {
        MenuBarExtra(store.menuBarTitle) {
            MenuContentView(store: store)
                .environment(\.locale, store.language.locale)
        }
        .menuBarExtraStyle(.window)

        Window("ConfBar", id: AppWindowID.settings) {
            SettingsView(store: store)
                .environment(\.locale, store.language.locale)
        }
        .defaultSize(width: SettingsWindowLayout.width, height: SettingsWindowLayout.height)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
