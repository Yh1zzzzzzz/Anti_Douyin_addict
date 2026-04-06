import Foundation

struct AppConstants {
    static let douyinDomains = [
        "www.douyin.com",
        "douyin.com",
        "live.douyin.com",
        "www.iesdouyin.com",
        "iesdouyin.com"
    ]
    
    static let hostsPath = "/etc/hosts"
    
    static let blockComment = "# DouyinAntiAddict - BLOCKED"
    
    static let pfAnchorName = "com.apple/douyin_anti_addict"
    
    static let pfAnchorPath = "/etc/pf.anchors/com.apple.douyin_anti_addict.conf"
    
    static let launchAgentIdentifier = "com.douyinantiaddict.launcher"
    
    static let settingsKey = "DouyinAntiAddictSettings"
    
    static let statsKey = "DouyinAntiAddictStats"
    
    static let monitorInterval: TimeInterval = 5.0
    
    static let defaultDailyLimitMinutes: Double = 60.0
}
