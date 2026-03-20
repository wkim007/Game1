import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AudioToolbox)
import AudioToolbox
#endif

final class HapticManager {
    static let shared = HapticManager()
    private static let vibrationEnabledKey = "vibration_enabled"

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.vibrationEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.vibrationEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.vibrationEnabledKey)
        }
    }

    private init() {}

    func playLineClear(lines: Int) {
        guard isEnabled else { return }

        #if canImport(UIKit)
        switch lines {
        case 4...:
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)
            vibrateFallback()
        case 2...3:
            let impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.prepare()
            impact.impactOccurred(intensity: 1.0)
            vibrateFallback()
        default:
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.prepare()
            impact.impactOccurred(intensity: 0.9)
        }
        #endif
    }

    private func vibrateFallback() {
        #if canImport(AudioToolbox)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        #endif
    }
}
