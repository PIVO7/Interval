import SwiftUI

enum AppTheme {
    static let felt = Color(red: 0.07, green: 0.38, blue: 0.28)
    static let feltDeep = Color(red: 0.04, green: 0.26, blue: 0.19)
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.90)
    static let ink = Color(red: 0.12, green: 0.14, blue: 0.16)
    static let coral = Color(red: 0.91, green: 0.42, blue: 0.22)
    static let gold = Color(red: 0.93, green: 0.72, blue: 0.18)
    static let sky = Color(red: 0.35, green: 0.62, blue: 0.78)
    static let held = Color(red: 0.95, green: 0.85, blue: 0.35)

    static let titleFont = Font.system(.largeTitle, design: .rounded).weight(.heavy)
    static let headlineFont = Font.system(.title2, design: .rounded).weight(.bold)
    static let bodyFont = Font.system(.body, design: .rounded).weight(.medium)
    static let captionFont = Font.system(.caption, design: .rounded).weight(.semibold)
}
