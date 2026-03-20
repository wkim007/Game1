import SwiftUI

@main
struct TetrisApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            "sound_enabled": true,
            "vibration_enabled": true,
            "show_next_piece": true,
            "timeout_enabled": false,
            "timeout_seconds": 60
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
