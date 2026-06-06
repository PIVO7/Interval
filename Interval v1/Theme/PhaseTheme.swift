import SwiftUI

/// A curated work/rest colour pairing for the active workout screen — a Pro
/// feature. Each phase renders a two-stop gradient (`base → deep`); the deep
/// stop is tuned for white-text contrast at the bottom of the screen, matching
/// the original Coral/Sage treatment (~4.3:1+).
///
/// Presets only — no free colour picker — so every combination keeps the white
/// timer text and controls legible and stays on-brand. Most pairs follow the
/// "warm = work, cool = rest" exercise convention; `indigo` inverts it for
/// variety.
struct PhaseTheme: Identifiable, Hashable, Sendable {
    let id: String
    /// Short display name shown in the picker (proper noun, not localised).
    let name: String
    let workBase: UInt32
    let workDeep: UInt32
    let restBase: UInt32
    let restDeep: UInt32
    /// Bottom stop of the celebration gradient on the finished screen; the top
    /// stop reuses `restDeep` so the finish reads as a deepened "rest".
    let finishedDeep: UInt32

    var workColors: [Color] { [Color(hex: workBase), Color(hex: workDeep)] }
    var restColors: [Color] { [Color(hex: restBase), Color(hex: restDeep)] }
    var finishedColors: [Color] { [Color(hex: restDeep), Color(hex: finishedDeep)] }

    /// Small diagonal swatch gradients for the picker UI.
    var workSwatch: LinearGradient {
        LinearGradient(colors: workColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var restSwatch: LinearGradient {
        LinearGradient(colors: restColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension PhaseTheme {
    /// The default — identical to the app's original hardcoded Coral/Sage look,
    /// so free users (and anyone who never changes it) see no difference.
    static let coral = PhaseTheme(
        id: "coral", name: "Koraal",
        workBase: 0xE8826B, workDeep: 0xC76A48,
        restBase: 0xA8B89C, restDeep: 0x5B8071,
        finishedDeep: 0x3D6353
    )

    static let sunset = PhaseTheme(
        id: "sunset", name: "Zonsondergang",
        workBase: 0xF2935C, workDeep: 0xD06E33,
        restBase: 0x8E7BB5, restDeep: 0x584A86,
        finishedDeep: 0x3C3160
    )

    static let magma = PhaseTheme(
        id: "magma", name: "Magma",
        workBase: 0xEC6A57, workDeep: 0xC8412F,
        restBase: 0x7E93B2, restDeep: 0x4C5F7C,
        finishedDeep: 0x35465E
    )

    static let berry = PhaseTheme(
        id: "berry", name: "Bessen",
        workBase: 0xE2738F, workDeep: 0xBE4A69,
        restBase: 0x5DAFA9, restDeep: 0x357E79,
        finishedDeep: 0x24524E
    )

    static let amber = PhaseTheme(
        id: "amber", name: "Amber",
        workBase: 0xF0AB54, workDeep: 0xCC8527,
        restBase: 0x84AE89, restDeep: 0x507F58,
        finishedDeep: 0x345B3D
    )

    static let indigo = PhaseTheme(
        id: "indigo", name: "Indigo",
        workBase: 0x7C88DE, workDeep: 0x4E5BBE,
        restBase: 0xE6A0A4, restDeep: 0xC06E76,
        finishedDeep: 0x8A4C55
    )

    /// All selectable themes, in picker order. `coral` first as the default.
    static let all: [PhaseTheme] = [coral, sunset, magma, berry, amber, indigo]

    static let `default`: PhaseTheme = coral

    /// Resolve a stored id back to a theme, falling back to the default if the
    /// id is unknown (e.g. a theme removed in a future version).
    static func theme(id: String) -> PhaseTheme {
        all.first { $0.id == id } ?? .default
    }
}
