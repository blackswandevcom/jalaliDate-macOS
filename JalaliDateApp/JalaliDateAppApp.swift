import SwiftUI

@main
struct JalaliDateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No GUI window for this app
        }
    }
}
