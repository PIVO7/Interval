import Foundation

extension Int {
    /// Formats a seconds-count as `mm:ss` (e.g. `90 → "1:30"`). Used by
    /// the HomeView and EditFavoriteSheet wheel-picker rows so a single
    /// formatter style stays consistent across the app.
    var asMinuteSecond: String {
        Duration.seconds(self).formatted(.time(pattern: .minuteSecond))
    }

    /// Compact workout-duration: `45s`, `1m`, `1m 10s`, `1h 5m`. Used
    /// in narrow stat columns (HomeView summary card, FinishedView
    /// stats card) where `Duration.formatted(.units(... .narrow))`
    /// breaks badly in Dutch locale because it inserts a comma
    /// (e.g. "1 m, 10 s") that the text renderer then wraps on.
    var asCompactDuration: String {
        if self < 60 { return "\(self)s" }
        if self < 3600 {
            let m = self / 60
            let s = self % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        let h = self / 3600
        let m = (self % 3600) / 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
