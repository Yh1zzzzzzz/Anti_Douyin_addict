import Foundation

class BlockManager {
    private let hostsURL = URL(fileURLWithPath: AppConstants.hostsPath)
    private let blockIP = "0.0.0.0"
    private let pfAnchorName = AppConstants.pfAnchorName
    private let pfAnchorPath = AppConstants.pfAnchorPath
    private let blockedDateKey = "DouyinAntiAddict_BlockedDate"
    private let blockedIPCacheKey = "DouyinAntiAddict_BlockedIPs"
    private let pfctlPath = "/sbin/pfctl"
    private let digPath = "/usr/bin/dig"
    private let publicDNSServers = ["1.1.1.1", "8.8.8.8", "223.5.5.5"]
    
    func isBlocked() -> Bool {
        return isHostsBlocked() || isPFBlockInstalled()
    }
    
    func isBlockedToday() -> Bool {
        guard isBlocked() else { return false }
        
        let savedDate = UserDefaults.standard.string(forKey: blockedDateKey) ?? ""
        let today = getTodayString()
        
        return savedDate == today
    }
    
    func isPFBlocked() -> Bool {
        isPFBlockInstalled()
    }
    
    func block() {
        let resolvedIPs = resolveDomainsToIPs()
        if !resolvedIPs.isEmpty {
            UserDefaults.standard.set(resolvedIPs, forKey: blockedIPCacheKey)
        }
        
        let pfBlocked = isPFBlockInstalled() || applyPFBlock(resolvedIPs)
        let hostsBlocked = isHostsBlocked() || applyHostsBlock()
        
        guard hostsBlocked || pfBlocked else {
            return
        }
        
        UserDefaults.standard.set(getTodayString(), forKey: blockedDateKey)
    }
    
    func unblock() {
        _ = removeHostsBlock()
        _ = removePFBlock()
        UserDefaults.standard.removeObject(forKey: blockedDateKey)
        UserDefaults.standard.removeObject(forKey: blockedIPCacheKey)
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
        !installedPFIPs().isEmpty
    }
    
    private func applyPFBlock(_ candidateIPs: [String] = []) -> Bool {
        let resolvedIPs = sanitizeResolvedIPs(candidateIPs).isEmpty
            ? cachedResolvedIPs()
            : sanitizeResolvedIPs(candidateIPs)
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
        let stateKillCommands = makePFStateKillCommands(for: resolvedIPs)
        
        let script = """
        do shell script "mkdir -p \(anchorDir) && echo '\(escapedRules)' > \(pfAnchorPath) && \(pfctlPath) -E >/dev/null 2>&1 && \(pfctlPath) -a \(pfAnchorName) -f \(pfAnchorPath) && \(stateKillCommands) || { rm -f \(pfAnchorPath); exit 1; }" with administrator privileges
        """
        
        return executeAppleScript(script)
    }
    
    private func removePFBlock() -> Bool {
        let clearScript = """
        do shell script "echo '' | \(pfctlPath) -a \(pfAnchorName) -f - 2>/dev/null; rm -f \(pfAnchorPath)" with administrator privileges
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
        
        return sanitizeResolvedIPs(Array(allIPs))
    }
    
    private func resolveDomain(_ domain: String) -> [String]? {
        let recordTypes = ["A", "AAAA"]
        var allIPs = Set<String>()
        
        for recordType in recordTypes {
            if let resolvedIPs = resolveDomain(domain, recordType: recordType) {
                allIPs.formUnion(resolvedIPs)
            }
        }
        
        return allIPs.isEmpty ? nil : Array(allIPs)
    }
    
    private func resolveDomain(_ domain: String, recordType: String) -> [String]? {
        for dnsServer in publicDNSServers {
            if let resolvedIPs = runDig(arguments: ["@\(dnsServer)", "+short", recordType, domain]) {
                return resolvedIPs
            }
        }
        
        return runDig(arguments: ["+short", recordType, domain])
    }
    
    private func runDig(arguments: [String]) -> [String]? {
        let process = Process()
        process.launchPath = digPath
        process.arguments = arguments
        
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
            
            let sanitizedIPs = sanitizeResolvedIPs(ips)
            return sanitizedIPs.isEmpty ? nil : sanitizedIPs
        } catch {
            return nil
        }
    }
    
    private func cachedResolvedIPs() -> [String] {
        let cachedIPs = UserDefaults.standard.stringArray(forKey: blockedIPCacheKey) ?? []
        return sanitizeResolvedIPs(cachedIPs)
    }
    
    private func installedPFIPs() -> [String] {
        guard let content = try? String(contentsOfFile: pfAnchorPath, encoding: .utf8) else {
            return []
        }
        
        let ips = content
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                guard !trimmed.hasPrefix("table"), !trimmed.hasPrefix("block"), trimmed != "}" else {
                    return nil
                }
                return trimmed.replacingOccurrences(of: ",", with: "")
            }
        
        return sanitizeResolvedIPs(ips)
    }
    
    private func sanitizeResolvedIPs(_ ips: [String]) -> [String] {
        let placeholderIPs: Set<String> = [
            "0.0.0.0",
            "::",
            "::1",
            "::ffff:0.0.0.0",
            "127.0.0.1",
            "::ffff:127.0.0.1"
        ]
        
        return Array(Set(
            ips
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .filter { !placeholderIPs.contains($0.lowercased()) }
        ))
    }
    
    private func makePFStateKillCommands(for resolvedIPs: [String]) -> String {
        resolvedIPs
            .map { ip in
                let anyAddress = ip.contains(":") ? "::/0" : "0.0.0.0/0"
                return "\(pfctlPath) -k \(anyAddress) -k \(ip) >/dev/null 2>&1 || true"
            }
            .joined(separator: " && ")
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
