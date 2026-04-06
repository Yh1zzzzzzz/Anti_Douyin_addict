import Foundation
import AppKit

class StatusBarManager: NSObject {
    var statusItem: NSStatusItem!
    var monitor: DouyinMonitor!
    var blockManager: BlockManager!
    var statsTracker: StatsTracker!
    var settingsManager: SettingsManager!
    var launchAgentManager: LaunchAgentManager!
    var timer: Timer?
    
    override init() {
        super.init()
        
        settingsManager = SettingsManager()
        blockManager = BlockManager()
        statsTracker = StatsTracker()
        monitor = DouyinMonitor()
        launchAgentManager = LaunchAgentManager()
        
        launchAgentManager.enableAutoStart()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBarIcon()
        updateMenu()
        
        timer = Timer.scheduledTimer(
            timeInterval: AppConstants.monitorInterval,
            target: self,
            selector: #selector(checkDouyinUsage),
            userInfo: nil,
            repeats: true
        )
    }
    
    @objc func checkDouyinUsage() {
        blockManager.checkAndResetIfNewDay()
        
        if blockManager.isBlockedToday() {
            return
        }
        
        let activeSeconds = monitor.getActiveDouyinSeconds()
        statsTracker.addSeconds(activeSeconds)
        
        let todaySeconds = statsTracker.getTodaySeconds()
        let limitSeconds = settingsManager.getDailyLimitSeconds()
        
        if todaySeconds >= limitSeconds {
            blockManager.block()
            updateStatusBarIcon()
            updateMenu()
            showBlockNotification()
        }
    }
    
    func updateMenu() {
        blockManager.checkAndResetIfNewDay()
        
        let menu = NSMenu()
        
        let isBlocked = blockManager.isBlockedToday()
        let todaySeconds = statsTracker.getTodaySeconds()
        let limitSeconds = settingsManager.getDailyLimitSeconds()
        
        let remainingSeconds = max(0, Int(limitSeconds) - Int(todaySeconds))
        let remainingText = formatTime(seconds: Double(remainingSeconds))
        let usedText = formatTime(seconds: todaySeconds)
        let limitText = formatTime(seconds: limitSeconds)
        
        if isBlocked {
            let statusItem = NSMenuItem(title: "抖音已拉黑", action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            menu.addItem(statusItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let infoItem = NSMenuItem(title: "今日已使用: \(usedText)", action: nil, keyEquivalent: "")
            infoItem.isEnabled = false
            menu.addItem(infoItem)
            
            let limitItem = NSMenuItem(title: "今日限额: \(limitText)", action: nil, keyEquivalent: "")
            limitItem.isEnabled = false
            menu.addItem(limitItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let lockedItem = NSMenuItem(title: "🔒 今日无法撤销", action: nil, keyEquivalent: "")
            lockedItem.isEnabled = false
            menu.addItem(lockedItem)
        } else {
            let statusItem = NSMenuItem(title: "抖音监控中", action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            menu.addItem(statusItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let usedItem = NSMenuItem(title: "今日已使用: \(usedText)", action: nil, keyEquivalent: "")
            usedItem.isEnabled = false
            menu.addItem(usedItem)
            
            let remainingItem = NSMenuItem(title: "剩余时间: \(remainingText)", action: nil, keyEquivalent: "")
            remainingItem.isEnabled = false
            menu.addItem(remainingItem)
            
            let limitItem = NSMenuItem(title: "每日限额: \(limitText)", action: nil, keyEquivalent: "")
            limitItem.isEnabled = false
            menu.addItem(limitItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: "")
            menu.addItem(settingsItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    func updateStatusBarIcon() {
        blockManager.checkAndResetIfNewDay()
        let isBlocked = blockManager.isBlockedToday()
        let iconText = isBlocked ? "🚫" : "⏱️"
        
        let button = statusItem.button!
        button.title = iconText
        button.toolTip = isBlocked ? "抖音已拉黑" : "抖音监控中"
    }
    
    @objc func openSettings() {
        let settingsWindow = SettingsWindow(settingsManager: settingsManager, statsTracker: statsTracker, blockManager: blockManager)
        settingsWindow.show()
    }
    
    @objc func quitApp() {
        cleanup()
        NSApplication.shared.terminate(nil)
    }
    
    func showBlockNotification() {
        let notification = NSUserNotification()
        notification.title = "抖音已拉黑"
        notification.informativeText = "今日使用时间已达上限，抖音已被拉黑，明日自动恢复。"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func formatTime(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d小时%d分钟", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d分钟%d秒", minutes, secs)
        } else {
            return String(format: "%d秒", secs)
        }
    }
    
    func cleanup() {
        timer?.invalidate()
        monitor.stop()
    }
}
