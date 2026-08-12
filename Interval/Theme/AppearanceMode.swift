import Foundation
import SwiftUI

/// User's preferred appearance for the app UI. `.system` defers to whatever
/// the device is set to; the other two force light/dark regardless.
enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    /// Returned as `LocalizedStringResource` so SwiftUI views can interpolate
    /// the values into `Text(...)` directly. Auto-extracts into the project's
    /// String Catalog with the source key matching the literal below.
    var displayName: LocalizedStringResource {
        switch self {
        case .system: "Systeem"
        case .light:  "Licht"
        case .dark:   "Donker"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .system: "Volg iPad / iPhone"
        case .light:  "Altijd licht"
        case .dark:   "Altijd donker"
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
