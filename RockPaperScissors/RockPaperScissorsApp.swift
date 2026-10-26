import SwiftUI

/// SwiftUI app entry point. v1's AppDelegate, SceneDelegate, and both
/// storyboards are gone: the scene lifecycle is the WindowGroup
/// below, and there is no launch storyboard to maintain.
@main
struct RockPaperScissorsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
