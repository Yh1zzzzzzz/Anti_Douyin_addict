import Foundation

class BlockManager {
    private let hostsURL = URL(fileURLWithPath: AppConstants.hostsPath)
    private let blockIP = "0.0.0.0"
    private let pfAnchorName = AppConstants.pfAnchorName
    private let pfAnchorPath = AppConstants.pfAnchorPath
    private let blockedDateKey = "DouyinAntiAddict_BlockedDate"
    
    func isBlocked() -> Bool {
        return isHostsBlocked() || isPFBlockInstalled()
    }
    
    func isBlockedToday() -> Bool {
        guard isBlocked() else { return false }
        
        let savedDate = UserDefaults.standard.string(forKey: blockedDateKey) ?? ""
        let today = getTodayString()
        
        return savedDate == today
    }
    
    func block() {
        guard !isBlocked() else { return }
        
        let hostsBlocked = applyHostsBlock()
        let pfBlocked = applyPFBlock()
        
        guard hostsBlocked || pfBlocked else {
            return
        }
        
        UserDefaults.standard.set(getTodayString(), forKey: blockedDateKey)
    }
    
    func unblock() {
        _ = removeHostsBlock()
        _ = removePFBlock()
        UserDefaults.standard.removeObject(forKey: blockedDateKey)
    }
    
    func checkAndResetIfNewDay() {
        if isBlocked() && !isBlockedToday() {
            unblock()
        }
    }
    
    // MARK: - Hosts blocking
    
    private func isHostsBlocked() -> Bool {
        guard let content = try? String(contentsOf: hostsURL, encoding: .utf8) else {
            return false
        }
        return content.contains(AppConstants.blockComment)
    }
    
    private func applyHostsBlock() -> Bool {
        guard !isHostsBlocked() else { return true }
        
        var lines: [String] = []
        if let content = try? String(contentsOf: hostsURL, encoding: .utf8) {
            lines = content.components(separatedBy: .newlines)
        }
        
        for domain in AppConstants.douyinDomains {
            let blockLine = "\(blockIP) \(domain) \(AppConstants.blockComment)"
            if !lines.contains(blockLine) {
                lines.append(blockLine)
            }
        }
        
        let newContent = lines.joined(separator: "\n") + "\n"
        return writeHostsFile(newContent)
    }
    
    private func removeHostsBlock() -> Bool {
        guard isHostsBlocked() else { return true }
        
        guard let content = try? String(contentsOf: hostsURL, encoding: .utf8) else { return false }
        
        let lines = content.components(separatedBy: .newlines)
        let filteredLines = lines.filter { !$0.contains(AppConstants.blockComment) }
        
        var newContent = filteredLines.joined(separator: "\n")
        if !newContent.hasSuffix("\n") {
            newContent += "\n"
        }
        
        return writeHostsFile(newContent)
    }
    
    private func writeHostsFile(_ content: String) -> Bool {
        let escaped = content.replacingOccurrences(of: "'", with: "'\\''")
        let script = "do shell script \"echo '\(escaped)' > \(AppConstants.hostsPath)\" with administrator privileges"
        return executeAppleScript(script)
    }
    
    // MARK: - pf firewall blocking
    
    private func isPFBlockInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: pfAnchorPath)
    }
    
    private func applyPFBlock() -> Bool {
        let resolvedIPs = resolveDomainsToIPs()
        guard !resolvedIPs.isEmpty else { return false }
        
        var pfRules = "table <douyin_blocked> {\n"
        for ip in resolvedIPs {
            pfRules += "    \(ip),\n"
        }
        pfRules += "}\n"
        pfRules += "block drop quick inet proto tcp from any to <douyin_blocked> port {80, 443}\n"
        pfRules += "block drop quick inet6 proto tcp from any to <douyin_blocked> port {80, 443}\n"
        pfRules += "block drop quick inet proto udp from any to <douyin_blocked> port 443\n"
        pfRules += "block drop quick inet6 proto udp from any to <douyin_blocked> port 443\n"
        
        let anchorDir = (pfAnchorPath as NSString).deletingLastPathComponent
        let escapedRules = pfRules.replacingOccurrences(of: "'", with: "'\\''")
        
        let script = """
        do shell script "mkdir -p \(anchorDir) && echo '\(escapedRules)' > \(pfAnchorPath) && pfctl -E >/dev/null 2>&1 && pfctl -a \(pfAnchorName) -f \(pfAnchorPath) || { rm -f \(pfAnchorPath); exit 1; }" with administrator privileges
        """
        
        return executeAppleScript(script)
    }
    
    private func removePFBlock() -> Bool {
        let clearScript = """
        do shell script "echo '' | pfctl -a \(pfAnchorName) -f - 2>/dev/null; rm -f \(pfAnchorPath)" with administrator privileges
        """
        return executeAppleScript(clearScript)
    }
    
    private func resolveDomainsToIPs() -> [String] {
        var allIPs = Set<String>()
        
        for domain in AppConstants.douyinDomains {
            if let ips = resolveDomain(domain) {
                allIPs.formUnion(ips)
            }
        }
        
        return Array(allIPs)
    }
    
    private func resolveDomain(_ domain: String) -> [String]? {
        let process = Process()
        process.launchPath = "/usr/bin/dig"
        process.arguments = ["+short", domain]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            
            let ips = output
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .filter { $0.contains(".") || $0.contains(":") }
                .filter { !$0.hasSuffix(".") }
            
            return ips.isEmpty ? nil : ips
        } catch {
            return nil
        }
    }
    
    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - Helper
    
    private func executeAppleScript(_ script: String) -> Bool {
        guard let result = runAppleScript(script) else { return false }
        return result.status == 0
    }
    
    private func runAppleScript(_ script: String) -> (output: String, status: Int32)? {
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
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, process.terminationStatus)
        } catch {
            print("Failed to execute script: \(error)")
            return nil
        }
    }
}
