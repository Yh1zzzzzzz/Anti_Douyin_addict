import SwiftUI

@main
struct DouyinAntiAddictApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarManager: StatusBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarManager = StatusBarManager()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarManager?.cleanup()
    }
}
