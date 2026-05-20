import SwiftUI

extension ActivityPhase {
    var symbol: String {
        switch self {
        case .countdown: "play.fill"
        case .work:      "flame.fill"
        case .rest:      "leaf.fill"
        case .finished:  "trophy.fill"
        }
    }

    var label: String {
        switch self {
        case .countdown: "Start..."
        case .work:      "WERK"
        case .rest:      "RUST"
        case .finished:  "Klaar"
        }
    }

    var tint: Color {
        switch self {
        case .countdown, .work: WidgetBrand.coral
        case .rest:             WidgetBrand.sage
        case .finished:         WidgetBrand.sageDeep
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .countdown, .work:
            LinearGradient(colors: [WidgetBrand.coral, WidgetBrand.coralDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rest:
            LinearGradient(colors: [WidgetBrand.sage, WidgetBrand.sageDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .finished:
            LinearGradient(colors: [WidgetBrand.sageDeep, WidgetBrand.forestDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
