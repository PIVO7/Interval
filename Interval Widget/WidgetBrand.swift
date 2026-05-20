import SwiftUI

/// Brand colours used inside the widget extension. Mirrors `AppTheme` in the
/// main app — duplicated here because Widget extensions can't import app
/// sources. Keep hex values in sync with `Interval v1/Theme/AppTheme.swift`.
enum WidgetBrand {
    static let coral      = Color(red: 0xE8/255, green: 0x82/255, blue: 0x6B/255)
    static let coralDeep  = Color(red: 0xC7/255, green: 0x6A/255, blue: 0x48/255)
    static let amber      = Color(red: 0xF4/255, green: 0xB8/255, blue: 0x60/255)
    static let sage       = Color(red: 0xA8/255, green: 0xB8/255, blue: 0x9C/255)
    static let sageDeep   = Color(red: 0x5B/255, green: 0x80/255, blue: 0x71/255)
    static let forestDeep = Color(red: 0x3D/255, green: 0x63/255, blue: 0x53/255)
}
