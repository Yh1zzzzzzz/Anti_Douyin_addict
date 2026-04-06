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
        guard !isAnotherInstanceRunning() else {
            NSApp.terminate(nil)
            return
        }
        
        NSApp.setActivationPolicy(.accessory)
        statusBarManager = StatusBarManager()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarManager?.cleanup()
    }
    
    private func isAnotherInstanceRunning() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }
        
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .contains { $0.processIdentifier != currentPID && !$0.isTerminated }
    }
}
