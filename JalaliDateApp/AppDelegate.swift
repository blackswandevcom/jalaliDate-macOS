import Cocoa
import SwiftUI
import UserNotifications

// Request notification permission
func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            print("Notification permission error: \(error)")
        } else if granted {
            print("Notification permission granted.")
        } else {
            print("Notification permission denied.")
        }
    }
}

// Function to get the current Jalali date in YYYY-mm-dd format
func getCurrentJalaliDate() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: currentDate)
}

// Function to get the current Jalali day as an integer (for the icon)
func getCurrentJalaliDay() -> Int {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    return calendar.component(.day, from: currentDate)
}

// Function to get the current Jalali day as an integer (for the icon)
func getCurrentJalaliMonthInt() -> Int {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    return calendar.component(.month, from: currentDate)
}

// Function to get the full Jalali month name
func getCurrentJalaliMonth() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "fa_IR")
    formatter.dateFormat = "MMMM" // Month name
    return formatter.string(from: currentDate)
}

// Function to get the current Jalali weekday name
func getCurrentJalaliWeekday() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "fa_IR")
    formatter.dateFormat = "EEEE" // Day of the week
    return formatter.string(from: currentDate)
}

// Function to get the current Gregorian date in YYYY-mm-dd format
func getCurrentGregorianDate() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: currentDate)
}

// Function to get the full Gregorian month name
func getCurrentGregorianMonth() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "MMMM" // Month name
    return formatter.string(from: currentDate)
}

// Function to get the current Gregorian weekday name
func getCurrentGregorianWeekday() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "EEEE" // Day of the week
    return formatter.string(from: currentDate)
}

// Function to display a notification using UserNotifications
func showCopyNotification(message: String) {
    let content = UNMutableNotificationContent()
    content.title = "Copied!"
    content.body = message
    content.sound = .default

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Notification error: \(error)")
        }
    }
}

// Helper function to check if today is Friday
func isTodayFriday() -> Bool {
    let calendar = Calendar(identifier: .gregorian)
    let today = Date()
    let weekday = calendar.component(.weekday, from: today)
    return weekday == 6 // 6 represents Friday in Gregorian calendar (1 = Sunday)
}


// Generate a rounded rectangular icon with a visible border and centered day text
func generateIcon(with day: Int) -> NSImage {
    let width: CGFloat = 20  // Icon width
    let height: CGFloat = 20 // Icon height
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    
    // Set colors to adapt based on system appearance using template
    let borderColor: NSColor = isTodayFriday() ? .red : .yellow
    let textColor: NSColor = .black  // Use black; macOS will invert in dark mode

    // Draw the rounded rectangle with a centered border
    let rectPath = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: width - 2, height: height - 2), xRadius: 10, yRadius: 10)
    borderColor.setStroke()
    rectPath.lineWidth = 1.5
    rectPath.stroke()
    
    // Draw the day number in the center
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10),  // Font size for day text
        .foregroundColor: textColor,  // Adaptive text color
        .paragraphStyle: paragraphStyle
    ]
    
    let dayString = "\(day)"
    let stringSize = dayString.size(withAttributes: attributes)
    let rect = NSRect(
        x: (width - stringSize.width) / 2,
        y: (height - stringSize.height) / 2,
        width: stringSize.width,
        height: stringSize.height
    )
    dayString.draw(in: rect, withAttributes: attributes)
    
    image.unlockFocus()
    
    // Set image as a template to automatically adapt to light/dark mode
    image.isTemplate = true
    
    return image
}


// AppDelegate to handle status bar item setup and menu
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the Dock icon programmatically
        NSApp.setActivationPolicy(.prohibited)
        
        requestNotificationPermission()
        
        // Create a status bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Set the initial icon with the current Jalali day
        updateIcon()

        // Set up the menu for the status item
        let menu = NSMenu()
        
        // Add Jalali date item (copyable)
        let jalaliDateItem = NSMenuItem(title: "Jalali Date: \(getCurrentJalaliDate())", action: #selector(copyJalaliDate), keyEquivalent: "c")
        jalaliDateItem.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Jalali Date")  // System icon example
        menu.addItem(jalaliDateItem)
        
        // Add Jalali month item (disabled)
        let jalaliMonthItem = NSMenuItem(title: "Jalali Month: \(getCurrentJalaliMonth())", action: nil, keyEquivalent: "")
        jalaliMonthItem.image = NSImage(systemSymbolName: "moon", accessibilityDescription: "Jalali Month Icon")  // System icon example
        jalaliMonthItem.isEnabled = false
        menu.addItem(jalaliMonthItem)
        
        // Add Jalali weekday item (disabled)
        let jalaliWeekdayItem = NSMenuItem(title: "Jalali Weekday: \(getCurrentJalaliWeekday())", action: nil, keyEquivalent: "")
        jalaliWeekdayItem.isEnabled = false
        jalaliWeekdayItem.image = NSImage(systemSymbolName: "calendar.circle", accessibilityDescription: "Gregorian Date Icon")  // System icon example
        menu.addItem(jalaliWeekdayItem)
        
        // Add a separator
        menu.addItem(NSMenuItem.separator())
        
        // Add Gregorian date item (copyable)
        let gregorianDateItem = NSMenuItem(title: "Gregorian Date: \(getCurrentGregorianDate())", action: #selector(copyGregorianDate), keyEquivalent: "x")
        gregorianDateItem.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Jalali Date")  // System icon example
        menu.addItem(gregorianDateItem)
        
        // Add Gregorian month item (disabled)
        let gregorianMonthItem = NSMenuItem(title: "Gregorian Month: \(getCurrentGregorianMonth())", action: nil, keyEquivalent: "")
        gregorianMonthItem.image = NSImage(systemSymbolName: "moon", accessibilityDescription: "Jalali Month Icon")  // System icon example
        gregorianMonthItem.isEnabled = false
        menu.addItem(gregorianMonthItem)
        
        // Add Gregorian weekday item (disabled)
        let gregorianWeekdayItem = NSMenuItem(title: "Gregorian Weekday: \(getCurrentGregorianWeekday())", action: nil, keyEquivalent: "")
        gregorianWeekdayItem.isEnabled = false
        gregorianWeekdayItem.image = NSImage(systemSymbolName: "calendar.circle", accessibilityDescription: "Gregorian Date Icon")  // System icon example
        menu.addItem(gregorianWeekdayItem)
        
        // Add a separator
        menu.addItem(NSMenuItem.separator())
        

        // About item with an icon
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "a")
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About Icon")  // System icon example
        menu.addItem(aboutItem)
        
        // Site item with an icon
        let siteItem = NSMenuItem(title: "Site", action: #selector(openSite), keyEquivalent: "s")
        siteItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Site Icon")  // System icon example
        menu.addItem(siteItem)
        
        // Quit item with an icon
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit Icon")  // System icon example
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        // Set the taskbar text to the current Jalali date in Persian format
        updateTaskbarTitle()
        
        // Update the icon daily
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            self.updateIcon()
        }
        // Update the date every minute
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.updateTaskbarTitle()
        }
        
        // Activate app on click to prioritize menu display
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(showMenu)


    }
    
    
    // Update the icon to show the current Jalali day
    func updateIcon() {
        let day = getCurrentJalaliDay()
        statusItem?.button?.image = generateIcon(with: day)
    }

    // Update the taskbar title to show the current day’s Jalali date in Persian
    func updateTaskbarTitle() {
        // let jalaliDate = getCurrentJalaliDate()
        statusItem?.button?.title = ""
    }
    
    // Show the menu and prioritize its display
    @objc func showMenu() {
        NSApp.activate(ignoringOtherApps: true)
        statusItem?.menu?.popUp(positioning: nil, at: .zero, in: statusItem?.button)
    }

    // Copy the Jalali date to the clipboard
    @objc func copyJalaliDate() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(getCurrentJalaliDate(), forType: .string)
        showCopyNotification(message: "Jalali Date Copied: \(getCurrentJalaliDate())")
    }
    
    // Copy the Gregorian date to the clipboard
    @objc func copyGregorianDate() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(getCurrentGregorianDate(), forType: .string)
        showCopyNotification(message: "Gregorian Date Copied: \(getCurrentGregorianDate())")
    }
    
    // Show an "About" dialog
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About JalaliDate-Toolbar"
        alert.informativeText = "This app displays the current Jalali and Gregorian dates in the menu bar.\n\nDeveloped by Amirhp.Com"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Thanks!")
        alert.runModal()
    }

    // Open the website
    @objc func openSite() {
        if let url = URL(string: "https://amirhp.com/") {
            NSWorkspace.shared.open(url)
        }
    }
    
}
