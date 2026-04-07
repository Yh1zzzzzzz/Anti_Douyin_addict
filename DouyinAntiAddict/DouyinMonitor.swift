import Foundation
import AppKit

class DouyinMonitor {
    private var isRunning = false
    private let browserApps = ["Safari", "Google Chrome", "Chrome", "Firefox", "Microsoft Edge", "Arc", "Brave Browser", "Opera"]
    
    init() {
        isRunning = true
    }
    
    func getActiveDouyinSeconds() -> Int {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        guard let appName = frontmostApp?.localizedName else { return 0 }
        
        guard browserApps.contains(appName) else { return 0 }
        
        guard let url = getBrowserURL(appName: appName) else { return 0 }
        
        if isDouyinURL(url) {
            return Int(AppConstants.monitorInterval)
        }
        
        return 0
    }
    
    func redirectActiveDouyinPageIfNeeded() {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        guard let appName = frontmostApp?.localizedName else { return }
        guard browserApps.contains(appName) else { return }
        guard let url = getBrowserURL(appName: appName), isDouyinURL(url) else { return }
        
        redirectCurrentTab(appName: appName)
    }
    
    private func getBrowserURL(appName: String) -> String? {
        switch appName {
        case "Safari":
            return getSafariURL()
        case "Google Chrome", "Chrome", "Arc", "Brave Browser":
            return getChromeBasedURL(appName)
        case "Firefox":
            return getFirefoxURL()
        case "Microsoft Edge":
            return getChromeBasedURL(appName)
        case "Opera":
            return getChromeBasedURL(appName)
        default:
            return nil
        }
    }
    
    private func isDouyinURL(_ urlString: String) -> Bool {
        guard let host = URLComponents(string: urlString)?.host?.lowercased() else {
            return false
        }
        
        return AppConstants.douyinDomains.contains { domain in
            let normalizedDomain = domain.lowercased()
            return host == normalizedDomain || host.hasSuffix(".\(normalizedDomain)")
        }
    }
    
    private func getSafariURL() -> String? {
        let appleScript = """
        tell application "Safari"
            if (count of windows) > 0 then
                if (count of tabs in window 1) > 0 then
                    return URL of current tab of window 1
                end if
            end if
        end tell
        """
        return executeAppleScript(appleScript)
    }
    
    private func getChromeBasedURL(_ appName: String) -> String? {
        let appleScript = """
        tell application "\(appName)"
            if (count of windows) > 0 then
                if (count of tabs in window 1) > 0 then
                    return URL of active tab in window 1
                end if
            end if
        end tell
        """
        return executeAppleScript(appleScript)
    }
    
    private func getFirefoxURL() -> String? {
        let appleScript = """
        tell application "Firefox"
            if (count of windows) > 0 then
                return get window 1's tab's url
            end if
        end tell
        """
        return executeAppleScript(appleScript)
    }
    
    private func redirectCurrentTab(appName: String) {
        let script: String
        
        switch appName {
        case "Safari":
            script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    if (count of tabs in window 1) > 0 then
                        set URL of current tab of window 1 to "about:blank"
                    end if
                end if
            end tell
            """
        case "Firefox":
            script = """
            tell application "Firefox"
                activate
            end tell
            tell application "System Events"
                keystroke "l" using command down
                keystroke "about:blank"
                key code 36
            end tell
            """
        default:
            script = """
            tell application "\(appName)"
                if (count of windows) > 0 then
                    if (count of tabs in window 1) > 0 then
                        set URL of active tab of window 1 to "about:blank"
                    end if
                end if
            end tell
            """
        }
        
        _ = executeAppleScript(script)
    }
    
    private func executeAppleScript(_ script: String) -> String? {
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", script]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    func stop() {
        isRunning = false
    }
}
