import Foundation

class LaunchAgentManager {
    private let agentIdentifier = AppConstants.launchAgentIdentifier
    private var agentFileName: String {
        "\(agentIdentifier).plist"
    }
    
    private var agentURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let libraryPath = home.appendingPathComponent("Library/LaunchAgents")
        return libraryPath.appendingPathComponent(agentFileName)
    }
    
    func enableAutoStart() {
        let appPath = Bundle.main.bundlePath
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(agentIdentifier)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appPath)/Contents/MacOS/DouyinAntiAddict</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
        
        do {
            let parentDir = agentURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            
            try plistContent.write(to: agentURL, atomically: true, encoding: .utf8)
            
            loadAgent()
        } catch {
            print("Failed to create LaunchAgent: \(error)")
        }
    }
    
    func disableAutoStart() {
        unloadAgent()
        
        do {
            if FileManager.default.fileExists(atPath: agentURL.path) {
                try FileManager.default.removeItem(at: agentURL)
            }
        } catch {
            print("Failed to remove LaunchAgent: \(error)")
        }
    }
    
    private func loadAgent() {
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["load", "-w", agentURL.path]
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to load LaunchAgent: \(error)")
        }
    }
    
    private func unloadAgent() {
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["unload", "-w", agentURL.path]
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Ignore errors if agent is not loaded
        }
    }
}
