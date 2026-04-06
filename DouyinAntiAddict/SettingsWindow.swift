import SwiftUI
import AppKit

class SettingsWindow {
    var window: NSWindow!
    
    init(settingsManager: SettingsManager, statsTracker: StatsTracker, blockManager: BlockManager) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "抖音防沉迷设置"
        window.center()
        window.contentView = NSHostingView(
            rootView: SettingsView(
                settingsManager: settingsManager,
                statsTracker: statsTracker,
                blockManager: blockManager
            )
        )
    }
    
    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    init(settingsManager: SettingsManager, statsTracker: StatsTracker, blockManager: BlockManager) {
        _viewModel = ObservedObject(
            wrappedValue: SettingsViewModel(
                settingsManager: settingsManager,
                statsTracker: statsTracker,
                blockManager: blockManager
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("抖音防沉迷设置")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                HStack {
                    Text("每日限额:")
                    TextField("分钟", value: $viewModel.dailyLimitMinutes, format: .number)
                        .frame(width: 80)
                    Text("分钟")
                }
                
                Divider()
                
                HStack {
                    Text("今日已使用:")
                    Spacer()
                    Text(viewModel.todayUsedText)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("剩余时间:")
                    Spacer()
                    Text(viewModel.remainingText)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.isBlocked ? .red : .green)
                }
                
                Divider()
                
                if viewModel.isBlocked {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.red)
                        Text("今日已拉黑，明日自动恢复")
                            .foregroundColor(.red)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("监控正常运行")
                            .foregroundColor(.green)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近7天使用情况:")
                        .fontWeight(.semibold)
                    
                    ForEach(viewModel.weeklyStats, id: \.date) { stat in
                        HStack {
                            Text(stat.date)
                                .frame(width: 80, alignment: .leading)
                            ProgressView(value: Double(stat.seconds) / 3600.0)
                                .frame(height: 8)
                            Text(formatTime(seconds: Double(stat.seconds)))
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                }
            }
            .padding()
            
            HStack {
                Button("保存设置") {
                    viewModel.saveSettings()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 400, height: 300)
    }
    
    func formatTime(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

class SettingsViewModel: ObservableObject {
    let settingsManager: SettingsManager
    let statsTracker: StatsTracker
    let blockManager: BlockManager
    
    @Published var dailyLimitMinutes: Double
    @Published var isBlocked: Bool
    @Published var todayUsedText: String
    @Published var remainingText: String
    @Published var weeklyStats: [StatsTracker.DayStats]
    
    init(settingsManager: SettingsManager, statsTracker: StatsTracker, blockManager: BlockManager) {
        self.settingsManager = settingsManager
        self.statsTracker = statsTracker
        self.blockManager = blockManager
        
        self.dailyLimitMinutes = settingsManager.getDailyLimitMinutes()
        if self.dailyLimitMinutes <= 0 {
            self.dailyLimitMinutes = AppConstants.defaultDailyLimitMinutes
        }
        
        self.isBlocked = blockManager.isBlockedToday()
        self.todayUsedText = ""
        self.remainingText = ""
        self.weeklyStats = []
        
        updateStats()
    }
    
    func updateStats() {
        let todaySeconds = statsTracker.getTodaySeconds()
        let limitSeconds = settingsManager.getDailyLimitSeconds()
        let remainingSeconds = max(0, limitSeconds - todaySeconds)
        
        todayUsedText = formatTime(seconds: todaySeconds)
        remainingText = formatTime(seconds: remainingSeconds)
        
        weeklyStats = statsTracker.getStatsForDays(7)
    }
    
    func saveSettings() {
        settingsManager.setDailyLimitMinutes(dailyLimitMinutes)
        updateStats()
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
}
