import SwiftUI

/// Shared animation presets so the whole app has a coherent motion language.
///
/// Use cases:
/// - `appSmooth`: phase transitions, general layout
/// - `appBounce`: celebratory moments (trophy entrance, GO! pop)
///
/// One-off micro-animations (press feedback ~0.12s) stay inline at their
/// call sites — they tend to need precise per-gesture tuning.
extension Animation {
    /// Natural-feeling spring with a tiny landing settle. ~0.4s effective.
    static let appSmooth = Animation.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0)

    /// Playful overshoot for celebratory moments. ~0.5s effective.
    static let appBounce = Animation.spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0)
}

extension AnyTransition {
    /// Accordion-style reveal: the inserted view scales up from 95% anchored
    /// at the top edge while fading in. Anchoring at `.top` makes the content
    /// feel like it grows out of the row that was tapped, rather than popping
    /// into place. Combines with a parent layout animation to push lower rows
    /// down at the same pace.
    static var accordion: AnyTransition {
        .scale(scale: 0.95, anchor: .top)
        .combined(with: .opacity)
    }
}
