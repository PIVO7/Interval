import Foundation
import Observation

enum AmbientSound: String, CaseIterable, Identifiable, Codable {
    case none       = "none"
    case rain       = "rain"
    case ocean      = "ocean"
    case forest     = "forest"
    case lofi       = "lofi"
    case whiteNoise = "white_noise"
    case brownNoise = "brown_noise"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:       return NSLocalizedString("Geen geluid", comment: "")
        case .rain:       return NSLocalizedString("Regen", comment: "")
        case .ocean:      return NSLocalizedString("Oceaangolven", comment: "")
        case .forest:     return NSLocalizedString("Bos / vogels", comment: "")
        case .lofi:       return NSLocalizedString("Lo-fi beats", comment: "")
        case .whiteNoise: return NSLocalizedString("White noise", comment: "")
        case .brownNoise: return NSLocalizedString("Brown noise", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .none:       return "speaker.slash.fill"
        case .rain:       return "cloud.rain.fill"
        case .ocean:      return "water.waves"
        case .forest:     return "tree.fill"
        case .lofi:       return "music.note"
        case .whiteNoise: return "waveform"
        case .brownNoise: return "waveform.badge.mic"
        }
    }
}

@Observable
final class AudioSettings {
    var ambientSound: AmbientSound {
        didSet { UserDefaults.standard.set(ambientSound.rawValue, forKey: "ambientSound") }
    }
    var ambientVolume: Float {
        didSet { UserDefaults.standard.set(ambientVolume, forKey: "ambientVolume") }
    }
    var signalTonesEnabled: Bool {
        didSet { UserDefaults.standard.set(signalTonesEnabled, forKey: "signalTones") }
    }
    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "haptics") }
    }

    init() {
        let sound = UserDefaults.standard.string(forKey: "ambientSound") ?? AmbientSound.none.rawValue
        self.ambientSound = AmbientSound(rawValue: sound) ?? .none
        let vol = UserDefaults.standard.float(forKey: "ambientVolume")
        self.ambientVolume = vol == 0 ? 0.5 : vol
        self.signalTonesEnabled = UserDefaults.standard.object(forKey: "signalTones") as? Bool ?? true
        self.hapticsEnabled = UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true
    }
}
