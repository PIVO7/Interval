import Foundation

enum GameMode: String, CaseIterable, Identifiable {
    case versusFriends
    case versusComputer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .versusFriends: return "Tegen elkaar"
        case .versusComputer: return "Tegen de computer"
        }
    }

    var subtitle: String {
        switch self {
        case .versusFriends: return "Beurten doorgeven op één apparaat"
        case .versusComputer: return "Solo tegen een slimme tegenstander"
        }
    }
}
