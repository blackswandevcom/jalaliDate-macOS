import Cocoa
import SwiftUI

// Function to get the current Jalali date in YYYY-mm-dd format
func getCurrentJalaliDate() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: currentDate)
}

// Function to get the current Gregorian date in YYYY-mm-dd format
func getCurrentGregorianDate() -> String {
    let currentDate = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: currentDate)
}

// AppDelegate to handle status bar item setup
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create a status bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Initialize with the current dates
        updateDateDisplay()

        // Update the date every minute
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.updateDateDisplay()
        }
    }

    // Function to update the status item with both Jalali and Gregorian dates
    func updateDateDisplay() {
        let jalaliDate = getCurrentJalaliDate()
        let gregorianDate = getCurrentGregorianDate()
        statusItem?.button?.title = "\(jalaliDate) | \(gregorianDate)"
    }
}