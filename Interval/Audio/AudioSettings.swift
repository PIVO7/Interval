import Foundation
import Observation

@MainActor
@Observable
final class AudioSettings {
    var signalTonesEnabled: Bool {
        didSet { UserDefaults.standard.set(signalTonesEnabled, forKey: "signalTones") }
    }
    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "haptics") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.signalTonesEnabled = defaults.object(forKey: "signalTones") as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: "haptics") as? Bool ?? true
    }
}
