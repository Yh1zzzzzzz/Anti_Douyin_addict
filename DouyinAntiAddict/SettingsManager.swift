import Foundation

class SettingsManager {
    private let userDefaults = UserDefaults.standard
    private let dailyLimitKey = "DouyinDailyLimitMinutes"
    
    func getDailyLimitMinutes() -> Double {
        return userDefaults.double(forKey: dailyLimitKey)
    }
    
    func getDailyLimitSeconds() -> Double {
        let minutes = getDailyLimitMinutes()
        if minutes <= 0 {
            return AppConstants.defaultDailyLimitMinutes * 60
        }
        return minutes * 60
    }
    
    func setDailyLimitMinutes(_ minutes: Double) {
        userDefaults.set(minutes, forKey: dailyLimitKey)
    }
    
    func isAutoStartEnabled() -> Bool {
        return userDefaults.bool(forKey: "DouyinAutoStartEnabled")
    }
    
    func setAutoStartEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: "DouyinAutoStartEnabled")
    }
}
