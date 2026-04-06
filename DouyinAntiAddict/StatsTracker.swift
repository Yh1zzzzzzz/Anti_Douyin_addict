import Foundation

class StatsTracker {
    private let userDefaults = UserDefaults.standard
    
    struct DayStats: Codable {
        var date: String
        var seconds: Int
    }
    
    func addSeconds(_ seconds: Int) {
        guard seconds > 0 else { return }
        
        let today = getTodayString()
        var allStats = getAllStats()
        
        if let index = allStats.firstIndex(where: { $0.date == today }) {
            allStats[index].seconds += seconds
        } else {
            allStats.append(DayStats(date: today, seconds: seconds))
        }
        
        allStats = cleanOldStats(allStats)
        
        if let encoded = try? JSONEncoder().encode(allStats) {
            userDefaults.set(encoded, forKey: AppConstants.statsKey)
        }
    }
    
    func getTodaySeconds() -> Double {
        let today = getTodayString()
        let allStats = getAllStats()
        
        if let todayStats = allStats.first(where: { $0.date == today }) {
            return Double(todayStats.seconds)
        }
        
        return 0
    }
    
    func getStatsForDays(_ days: Int) -> [DayStats] {
        let allStats = getAllStats().sorted { $0.date < $1.date }
        return Array(allStats.suffix(days))
    }
    
    private func getAllStats() -> [DayStats] {
        guard let data = userDefaults.data(forKey: AppConstants.statsKey) else {
            return []
        }
        
        return (try? JSONDecoder().decode([DayStats].self, from: data)) ?? []
    }
    
    private func cleanOldStats(_ stats: [DayStats]) -> [DayStats] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        let cutoffString = formatDate(cutoffDate)
        
        return stats.filter { $0.date >= cutoffString }
    }
    
    private func getTodayString() -> String {
        return formatDate(Date())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
