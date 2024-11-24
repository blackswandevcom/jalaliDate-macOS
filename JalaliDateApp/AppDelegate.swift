import Cocoa
import SwiftUI
import UserNotifications
import Foundation

func getJalaliDateString() -> String {
    let persianCalendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = persianCalendar
    formatter.locale = Locale(identifier: "fa_IR")  // Persian locale for correct formatting
    formatter.dateFormat = "EEEE d MMMM yyyy"  // Example format for day, date, month, and year
    
    // let persianDate = formatter.string(from: Date())
    // return persianDate
    
    // Step 3: Format the date in Persian and convert digits to English
    let persianDateWithPersianNumbers = formatter.string(from: Date())
    let englishDigitsDate = convertPersianNumbersToEnglish(persianDateWithPersianNumbers)
    
    return englishDigitsDate
}
func getGregorianDateString() -> String {
    let gregorianCalendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = gregorianCalendar
    formatter.locale = Locale(identifier: "en_US")  // Persian locale for day and month names in Persian
    formatter.dateFormat = "EEEE d MMMM yyyy"  // Format to match the Jalali example
    
    let gregorianDate = formatter.string(from: Date())
    return gregorianDate
}

// Helper function to convert Persian digits to English digits
func convertPersianNumbersToEnglish(_ persianString: String) -> String {
    let persianDigits = ["۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
                         "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"]
    var englishString = persianString
    for (persian, english) in persianDigits {
        englishString = englishString.replacingOccurrences(of: persian, with: english)
    }
    return englishString
}

// Request notification permission
func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
        granted, error in
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
    formatter.dateFormat = "MMMM"  // Month name
    return formatter.string(from: currentDate)
}

// Function to get the current Jalali weekday name
func getCurrentJalaliWeekday() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "fa_IR")
    formatter.dateFormat = "EEEE"  // Day of the week
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
    formatter.dateFormat = "MMMM"  // Month name
    return formatter.string(from: currentDate)
}

// Function to get the current Gregorian weekday name
func getCurrentGregorianWeekday() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "EEEE"  // Day of the week
    return formatter.string(from: currentDate)
}


// Helper function to check if today is Friday
func isTodayFriday() -> Bool {
    let calendar = Calendar(identifier: .gregorian)
    let today = Date()
    let weekday = calendar.component(.weekday, from: today)
    return weekday == 6  // 6 represents Friday in Gregorian calendar (1 = Sunday)
}

// Generate a rounded rectangular icon with a visible border and centered day text
func generateIcon(with day: String) -> NSImage {
    let width: CGFloat = 20  // Icon width
    let height: CGFloat = 20  // Icon height
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    
    // Set colors to adapt based on system appearance using template
    let borderColor: NSColor = isTodayFriday() ? .red : .yellow
    let textColor: NSColor = .black  // Use black; macOS will invert in dark mode
    
    // Draw the rounded rectangle with a centered border
    let rectPath = NSBezierPath(
        roundedRect: NSRect(x: 1, y: 1, width: width - 2, height: height - 2), xRadius: 10,
        yRadius: 10)
    borderColor.setStroke()
    rectPath.lineWidth = 1.5
    rectPath.stroke()
    
    // Draw the day number in the center
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10),  // Font size for day text
        .foregroundColor: textColor,  // Adaptive text color
        .paragraphStyle: paragraphStyle,
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

class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var statusItem: NSStatusItem?
    
    // Sample data for the table
    let data = [
        ["1", "January", "فروردین", "۱"],
        ["2", "February", "اردیبهشت", "۲"],
        ["3", "March", "خرداد", "۳"],
        ["4", "April", "تیر", "۴"],
        ["5", "May", "مرداد", "۵"],
        ["6", "June", "شهریور", "۶"],
        ["7", "July", "مهر", "۷"],
        ["8", "August", "آبان", "۸"],
        ["9", "September", "آذر", "۹"],
        ["10", "October", "دی", "۱۰"],
        ["11", "November", "بهمن", "۱۱"],
        ["12", "December", "اسفند", "۱۲"],
    ]
    
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
        let jalaliMonthItem = NSMenuItem(title: "\(getJalaliDateString())", action: nil, keyEquivalent: "")
        jalaliMonthItem.image = NSImage(systemSymbolName: "moon", accessibilityDescription: "Jalali Month Icon")  // System icon example
        jalaliMonthItem.isEnabled = false
        menu.addItem(jalaliMonthItem)
        
        // Add a separator
        menu.addItem(NSMenuItem.separator())
        
        // Add Gregorian date item (copyable)
        let gregorianDateItem = NSMenuItem(title: "Gregorian Date: \(getCurrentGregorianDate())", action: #selector(copyGregorianDate), keyEquivalent: "x")
        gregorianDateItem.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Jalali Date")  // System icon example
        menu.addItem(gregorianDateItem)
        
        // Add Gregorian month item (disabled)
        let gregorianMonthItem = NSMenuItem(title: "\(getGregorianDateString())", action: nil, keyEquivalent: "")
        gregorianMonthItem.image = NSImage(systemSymbolName: "moon", accessibilityDescription: "Jalali Month Icon")  // System icon example
        gregorianMonthItem.isEnabled = false
        menu.addItem(gregorianMonthItem)
        
        
        // Add a separator
        menu.addItem(NSMenuItem.separator())
        

        
        // Add Jalali date item (copyable
        let gePersian = NSMenuItem(title: "Copy Version Number", action: #selector(copyVersionDate), keyEquivalent: "d")
        gePersian.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Jalali Date")  // System icon example
        menu.addItem(gePersian)
        
        // Add Jalali month item (disabled)
        let gePersianMuted = NSMenuItem(title: "\(getCurrentGregorianDate()) | \(getCurrentJalaliDate())", action: nil, keyEquivalent: "")
        gePersianMuted.image = NSImage(systemSymbolName: "moon", accessibilityDescription: "Jalali Month Icon")  // System icon example
        gePersianMuted.isEnabled = false
        menu.addItem(gePersianMuted)

        
        // Add a separator
        menu.addItem(NSMenuItem.separator())
        
        
        // About item with an icon
        let gmItem = NSMenuItem(title: "Months Table", action: #selector(showMonthTableAlert), keyEquivalent: "")
        gmItem.image = NSImage(systemSymbolName: "tablecells.fill", accessibilityDescription: "Months Table Icon")  // System icon example
        menu.addItem(gmItem)
        
        
        // Add a separator
        menu.addItem(NSMenuItem.separator())
        
        // About item with an icon
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About Icon")  // System icon example
        menu.addItem(aboutItem)
        
        // Site item with an icon
        let siteItem = NSMenuItem(title: "Site", action: #selector(openSite), keyEquivalent: "")
        siteItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Site Icon")  // System icon example
        menu.addItem(siteItem)
        
        // Quit item with an icon
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit Icon")  // System icon example
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        // Set the taskbar text to the current Jalali date in Persian format
        updateTaskbarTitle()
        
        // Update the icon daily
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
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
        statusItem?.button?.image = generateIcon(with: "\(day)")
    }
    
    // Update the taskbar title to show the current day’s Jalali date in Persian
    func updateTaskbarTitle() {
        // let jalaliDate = getCurrentJalaliDate()
        statusItem?.button?.title = ""
    }
    
    // Function to display a notification using UserNotifications
    func showCopyNotification(message: String) {
        // statusItem?.button?.title = "Copied !";
        statusItem?.button?.image = generateIcon(with: "✓")
        // Update the date every minute
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            self.updateIcon()
        }
        
    //    let content = UNMutableNotificationContent()
    //    content.title = "Copied!"
    //    content.body = message
    //    content.sound = .default
    //
    //    let request = UNNotificationRequest(
    //        identifier: UUID().uuidString, content: content, trigger: nil)
    //    UNUserNotificationCenter.current().add(request) { error in
    //        if let error = error {
    //            print("Notification error: \(error)")
    //        }
    //    }
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
    
    
    @objc func copyVersionDate() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(getCurrentGregorianDate()) | \(getCurrentJalaliDate())", forType: .string)
        showCopyNotification(message: "Version Date copied Sucessfully")
    }
    
    
    
    @objc func showMonthTableAlert() {
        let alert = NSAlert()
        alert.messageText = "Gregorian and Jalali Months"
        alert.alertStyle = .informational

        // Create the table view
        let tableView = NSTableView()
        tableView.rowSizeStyle = .medium
        tableView.headerView = nil  // Remove header if not needed

        // Define columns for the table with custom widths
        let columns = [
            ("Number", "number", 40.0),
            ("Gregorian Month", "gregorian", 80.0),
            ("Jalali Month", "jalali", 80.0),
            ("Number", "number", 40.0),
        ]
        
        for (title, identifier, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width  // Set custom width for each column
            tableView.addTableColumn(column)
        }

        // Set up the data source and delegate
        tableView.dataSource = self
        tableView.delegate = self
        
        // Calculate the height of the table based on the row count and row height
        let tableHeight = CGFloat(data.count) * tableView.rowHeight
        
        // Set the frame for the table directly
        tableView.frame = NSRect(x: 0, y: 0, width: 300, height: tableHeight)

        // Add the table directly as the alert's accessory view
        alert.accessoryView = tableView

        // Show the alert
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        alert.runModal()
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return data.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // let cellIdentifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        
        // Create a text field for each cell
        let cell = NSTextField(labelWithString: "")
        cell.isBordered = false
        cell.backgroundColor = .clear
        cell.alignment = .center

        // Populate each cell based on the column
        if let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn!) {
            cell.stringValue = data[row][columnIndex]
        }
        
        return cell
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
        alert.informativeText = """
        Version 4.0 | 2024-11-24 | 1403-09-04

        JalaliDate-Toolbar shows Jalali and Gregorian dates in your menu bar, with shortcuts for quick copying. Simple, lightweight, and efficient.
        """
        alert.alertStyle = .informational
        
        // Add a button for "Thanks!"
        alert.addButton(withTitle: "Close")
        
        // Add a second button for "Visit Website"
        alert.addButton(withTitle: "Visit Amirhp.Com")
        
        // Ensure the alert opens as the front window
        NSApp.activate(ignoringOtherApps: true) // Bring app to the front
        alert.window.level = .floating // Set alert as a floating window

        // Handle button response
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Open the URL when the "Visit Amirhp.Com" button is clicked
            if let url = URL(string: "https://amirhp.com") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // Function to handle the hyperlink click
    @objc func openLink(_ sender: NSTextField) {
        if let link = sender.attributedStringValue.attribute(.link, at: 0, effectiveRange: nil) as? URL {
            NSWorkspace.shared.open(link)
        }
    }
    
    
    // Open the website
    @objc func openSite() {
        if let url = URL(string: "https://amirhp.com/") {
            NSWorkspace.shared.open(url)
        }
    }
    
}
