import Foundation

public enum ActivityPhase: String, Codable, Hashable, Sendable {
    case countdown
    case work
    case rest
    case finished
}
