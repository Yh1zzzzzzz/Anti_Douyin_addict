import Foundation
import AppKit
import UserNotifications

class StatusBarManager: NSObject, UNUserNotificationCenterDelegate {
    private let statusBarLogoName = NSImage.Name("StatusBarLogo")
    var statusItem: NSStatusItem!
    var monitor: DouyinMonitor!
    var blockManager: BlockManager!
    var statsTracker: StatsTracker!
    var settingsManager: SettingsManager!
    var launchAgentManager: LaunchAgentManager!
    var settingsWindow: SettingsWindow?
    var timer: Timer?
    
    override init() {
        super.init()
        
        settingsManager = SettingsManager()
        blockManager = BlockManager()
        statsTracker = StatsTracker()
        monitor = DouyinMonitor()
        launchAgentManager = LaunchAgentManager()
        
        launchAgentManager.enableAutoStart()
        configureNotifications()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        DispatchQueue.main.async { [weak self] in
            self?.refreshStatusUI()
        }
        
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
        
        defer {
            refreshStatusUI()
        }
        
        if blockManager.isBlockedToday() {
            return
        }
        
        let activeSeconds = monitor.getActiveDouyinSeconds()
        statsTracker.addSeconds(activeSeconds)
        
        let todaySeconds = statsTracker.getTodaySeconds()
        let limitSeconds = settingsManager.getDailyLimitSeconds()
        
        if todaySeconds >= limitSeconds {
            blockManager.block()
            showBlockNotification()
        }
    }
    
    func refreshStatusUI() {
        updateStatusBarIcon()
        updateMenu()
    }
    
    func updateMenu() {
        blockManager.checkAndResetIfNewDay()
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
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
            
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let openWindowItem = NSMenuItem(title: "打开界面...", action: #selector(openSettings), keyEquivalent: "")
        openWindowItem.target = self
        openWindowItem.isEnabled = true
        menu.addItem(openWindowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    func updateStatusBarIcon() {
        blockManager.checkAndResetIfNewDay()
        let isBlocked = blockManager.isBlockedToday()
        
        let button = statusItem.button!
        button.title = ""
        button.imagePosition = .imageOnly
        button.image = makeStatusBarImage()
        button.toolTip = isBlocked ? "抖音已拉黑" : "抖音监控中"
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(
                settingsManager: settingsManager,
                statsTracker: statsTracker,
                blockManager: blockManager,
                onSettingsSaved: { [weak self] in
                    self?.refreshStatusUI()
                }
            )
        }
        DispatchQueue.main.async { [weak self] in
            self?.settingsWindow?.show()
        }
    }
    
    @objc func quitApp() {
        cleanup()
        NSApplication.shared.terminate(nil)
    }
    
    func showBlockNotification() {
        let content = UNMutableNotificationContent()
        content.title = "抖音已拉黑"
        content.body = "今日使用时间已达上限，抖音已被拉黑，明日自动恢复。"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "douyin-limit-reached",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
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
    
    private func makeStatusBarImage() -> NSImage? {
        guard let image = NSImage(named: statusBarLogoName)?.copy() as? NSImage else {
            return nil
        }
        
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }
    
    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
