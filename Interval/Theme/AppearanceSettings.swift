import Foundation
import Observation

/// Persisted user choice of light / dark / system appearance.
///
/// Stored in `UserDefaults` under `appearanceMode`. Read once at init,
/// written through on every change via `didSet` so SwiftUI views observe
/// the change immediately and the next launch restores the choice.
@MainActor
@Observable
final class AppearanceSettings {
    var mode: AppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey) }
    }

    /// Selected work/rest colour theme for the active workout screen (a Pro
    /// feature). Stored by id so unknown values gracefully fall back to the
    /// default. Defaults to `coral` — the app's original look.
    var phaseThemeID: String {
        didSet { UserDefaults.standard.set(phaseThemeID, forKey: Self.themeKey) }
    }

    private static let storageKey = "appearanceMode"
    private static let themeKey = "phaseThemeID"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
            ?? AppearanceMode.system.rawValue
        self.mode = AppearanceMode(rawValue: raw) ?? .system
        self.phaseThemeID = UserDefaults.standard.string(forKey: Self.themeKey)
            ?? PhaseTheme.default.id
    }

    /// Resolved theme for the current selection.
    var phaseTheme: PhaseTheme { PhaseTheme.theme(id: phaseThemeID) }
}
