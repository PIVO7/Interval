import Foundation
import Observation

/// Persisted user choice of light / dark / system appearance.
///
/// Stored in `UserDefaults` under `appearanceMode`. Read once at init,
/// written through on every change via `didSet` so SwiftUI views observe
/// the change immediately and the next launch restores the choice.
@Observable
final class AppearanceSettings {
    var mode: AppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey) }
    }

    @ObservationIgnored private static let storageKey = "appearanceMode"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
            ?? AppearanceMode.system.rawValue
        self.mode = AppearanceMode(rawValue: raw) ?? .system
    }
}
