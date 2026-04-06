import SwiftUI
import AppKit

class SettingsWindow {
    private let viewModel: SettingsViewModel
    var window: NSWindow!
    
    init(
        settingsManager: SettingsManager,
        statsTracker: StatsTracker,
        blockManager: BlockManager,
        onSettingsSaved: @escaping () -> Void = {}
    ) {
        viewModel = SettingsViewModel(
            settingsManager: settingsManager,
            statsTracker: statsTracker,
            blockManager: blockManager,
            onSettingsSaved: onSettingsSaved
        )
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "抖音防沉迷设置"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        window.contentView = NSHostingView(
            rootView: SettingsView(viewModel: viewModel)
        )
    }
    
    func show() {
        viewModel.reloadFromSettings()
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("抖音防沉迷设置")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView {
                VStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("每日限额:")
                            Spacer()
                            Text("\(viewModel.dailyLimitDisplayText) 分钟")
                                .fontWeight(.semibold)
                                .frame(width: 90, alignment: .trailing)
                            Stepper("", value: $viewModel.dailyLimitMinutes, in: 1...720, step: 1)
                                .labelsHidden()
                        }
                        
                        Slider(value: $viewModel.dailyLimitMinutes, in: 1...720, step: 1)
                        
                        Text("拖动滑块或点击步进器即可自动保存，范围 1-720 分钟")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                .frame(maxWidth: .infinity)
            }
            
            HStack {
                Text(viewModel.saveStatusText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("恢复默认 60 分钟") {
                    viewModel.resetToDefault()
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 460, height: 460)
        .onChange(of: viewModel.dailyLimitMinutes) { _ in
            viewModel.handleDailyLimitChanged()
        }
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
    private let onSettingsSaved: () -> Void
    private var isReloading = false
    
    @Published var dailyLimitMinutes: Double
    @Published var isBlocked: Bool
    @Published var todayUsedText: String
    @Published var remainingText: String
    @Published var weeklyStats: [StatsTracker.DayStats]
    @Published var saveStatusText: String
    
    init(
        settingsManager: SettingsManager,
        statsTracker: StatsTracker,
        blockManager: BlockManager,
        onSettingsSaved: @escaping () -> Void
    ) {
        self.settingsManager = settingsManager
        self.statsTracker = statsTracker
        self.blockManager = blockManager
        self.onSettingsSaved = onSettingsSaved
        
        let savedLimit = settingsManager.getDailyLimitMinutes()
        let dailyLimitMinutes = savedLimit > 0 ? savedLimit : AppConstants.defaultDailyLimitMinutes
        self.dailyLimitMinutes = Self.clampMinutes(dailyLimitMinutes)
        
        self.isBlocked = blockManager.isBlockedToday()
        self.todayUsedText = ""
        self.remainingText = ""
        self.weeklyStats = []
        self.saveStatusText = ""
        
        reloadFromSettings()
    }
    
    var dailyLimitDisplayText: String {
        Self.formatMinutes(dailyLimitMinutes)
    }
    
    func reloadFromSettings() {
        let savedLimit = settingsManager.getDailyLimitMinutes()
        let dailyLimitMinutes = savedLimit > 0 ? savedLimit : AppConstants.defaultDailyLimitMinutes
        isReloading = true
        self.dailyLimitMinutes = Self.clampMinutes(dailyLimitMinutes)
        isReloading = false
        saveStatusText = "当前已保存 \(Self.formatMinutes(self.dailyLimitMinutes)) 分钟"
        updateStats()
    }
    
    func updateStats() {
        let todaySeconds = statsTracker.getTodaySeconds()
        let limitSeconds = settingsManager.getDailyLimitSeconds()
        let remainingSeconds = max(0, limitSeconds - todaySeconds)
        
        isBlocked = blockManager.isBlockedToday()
        todayUsedText = formatTime(seconds: todaySeconds)
        remainingText = formatTime(seconds: remainingSeconds)
        
        weeklyStats = statsTracker.getStatsForDays(7)
    }
    
    func saveSettings() {
        let minutes = Self.clampMinutes(dailyLimitMinutes)
        dailyLimitMinutes = minutes
        settingsManager.setDailyLimitMinutes(minutes)
        saveStatusText = "已自动保存为 \(Self.formatMinutes(minutes)) 分钟"
        updateStats()
        onSettingsSaved()
    }
    
    func handleDailyLimitChanged() {
        guard !isReloading else {
            return
        }
        
        saveSettings()
    }
    
    func resetToDefault() {
        dailyLimitMinutes = AppConstants.defaultDailyLimitMinutes
        saveSettings()
    }
    
    private static func clampMinutes(_ minutes: Double) -> Double {
        min(max(minutes.rounded(), 1), 720)
    }
    
    private static func formatMinutes(_ minutes: Double) -> String {
        String(Int(clampMinutes(minutes)))
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
