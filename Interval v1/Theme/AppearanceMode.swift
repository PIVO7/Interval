import Foundation
import SwiftUI

/// User's preferred appearance for the app UI. `.system` defers to whatever
/// the device is set to; the other two force light/dark regardless.
enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: NSLocalizedString("Systeem", comment: "Appearance mode: follow the system setting")
        case .light:  NSLocalizedString("Licht", comment: "Appearance mode: force light")
        case .dark:   NSLocalizedString("Donker", comment: "Appearance mode: force dark")
        }
    }

    var subtitle: String {
        switch self {
        case .system: NSLocalizedString("Volg iPad / iPhone", comment: "Subtitle for system appearance mode")
        case .light:  NSLocalizedString("Altijd licht", comment: "Subtitle for light appearance mode")
        case .dark:   NSLocalizedString("Altijd donker", comment: "Subtitle for dark appearance mode")
        }
    }

    var icon: String {
        switch self {
        case .system: "iphone"
        case .light:  "sun.max.fill"
        case .dark:   "moon.stars.fill"
        }
    }

    /// Returns nil for `.system` so SwiftUI's `preferredColorScheme(nil)`
    /// inherits the device's current setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}
