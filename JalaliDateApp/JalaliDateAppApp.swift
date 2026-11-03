import SwiftUI

@main
struct JalaliDateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No GUI window for this app
        }
        .commands {
            // jDate › Settings… (⌘,) opens the main window instead of the empty Settings scene.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { appDelegate.model.open(.general) }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
