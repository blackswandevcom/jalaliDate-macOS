import Cocoa
import SwiftUI
import UserNotifications
import Foundation

var islamicDateOffset: Int {
    get {
        UserDefaults.standard.integer(forKey: "IslamicDateOffset")
    }
    set {
        UserDefaults.standard.set(newValue, forKey: "IslamicDateOffset")
    }
}

class DateConverterWindowController: NSWindowController {
    private var statusItem: NSStatusItem?

    convenience init(statusItem: NSStatusItem?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400), // Increased height to accommodate new layout
            styleMask: [.titled, .closable], // Restore border and title bar
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.level = .floating // Keep window on top
        window.hasShadow = true
        window.backgroundColor = .windowBackgroundColor // Set a standard background color
        window.isOpaque = true
        window.center() // Center the window

        self.init(window: window)
        
        self.statusItem = statusItem

        let contentVC = DateConverterViewController()
        window.contentViewController = contentVC
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}


class DateConverterViewController: NSViewController {
    // Gregorian controls
    private let gregorianLabel = NSTextField(labelWithString: "Gregorian")
    private let gregorianYear = NSStepper()
    private let gregorianYearField = NSTextField() // New text field for year
    private let gregorianMonth = NSPopUpButton()
    private let gregorianDay = NSStepper()
    private let gregorianDayField = NSTextField() // New text field for day
    
    // Jalali controls
    private let jalaliLabel = NSTextField(labelWithString: "Jalali")
    private let jalaliYear = NSStepper()
    private let jalaliYearField = NSTextField() // New text field for year
    private let jalaliMonth = NSPopUpButton()
    private let jalaliDay = NSStepper()
    private let jalaliDayField = NSTextField() // New text field for day
    
    // Islamic controls
    private let islamicLabel = NSTextField(labelWithString: "Islamic")
    private let islamicYear = NSStepper()
    private let islamicYearField = NSTextField() // New text field for year
    private let islamicMonth = NSPopUpButton()
    private let islamicDay = NSStepper()
    private let islamicDayField = NSTextField() // New text field for day
    
    // Navigation buttons
    private let prevButton = NSButton(title: "Prev", target: nil, action: nil)
    private let todayButton = NSButton(title: "Today", target: nil, action: nil)
    private let nextButton = NSButton(title: "Next", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    
    // Summary
    private let summaryLabel = NSTextField(labelWithString: "")
    
    // Separators
    private let separator1 = NSBox()
    private let separator2 = NSBox()
    
    private var lastEditedCalendar: String = "gregorian"
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        setupUI()
        setupConstraints()
        setupCalendars()
        setupBindings()
    }
    
    private func setupUI() {
        // Configure labels
        [gregorianLabel, jalaliLabel, islamicLabel].forEach {
            $0.isEditable = false
            $0.isBezeled = false
            $0.backgroundColor = .clear
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = NSFont.boldSystemFont(ofSize: 14)
        }

        // Configure steppers for year and day
        [gregorianYear, gregorianDay, jalaliYear, jalaliDay, islamicYear, islamicDay].forEach {
            $0.isEnabled = true
            $0.target = self
            $0.action = #selector(stepperDidChange(_:))
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.increment = 1
            $0.valueWraps = false
            if $0 == gregorianYear || $0 == jalaliYear || $0 == islamicYear {
                $0.minValue = 1
                $0.maxValue = 9999
            } else {
                $0.minValue = 1
                $0.maxValue = 31
            }
        }

        // Configure text fields for year and day
        [gregorianYearField, gregorianDayField, jalaliYearField, jalaliDayField, islamicYearField, islamicDayField].forEach {
            $0.isEditable = false // Make them read-only
            $0.isBezeled = true
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.alignment = .center
            $0.stringValue = "0" // Initial value
        }

        // Configure dropdowns
        [gregorianMonth, jalaliMonth, islamicMonth].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.frame = NSRect(x: 0, y: 0, width: 120, height: 24)
        }
        
        // Configure navigation buttons
        [prevButton, todayButton, nextButton, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.target = self
            $0.action = $0 == prevButton ? #selector(previousDate) :
                        $0 == todayButton ? #selector(setToday) :
                        $0 == nextButton ? #selector(nextDate) :
                        #selector(closeWindow)
        }
        
        // Configure summary label
        summaryLabel.isEditable = false
        summaryLabel.isBezeled = false
        summaryLabel.backgroundColor = .clear
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure separators
        [separator1, separator2].forEach {
            $0.boxType = .separator
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        // Add subviews
        view.addSubview(gregorianLabel)
        view.addSubview(gregorianYear)
        view.addSubview(gregorianYearField)
        view.addSubview(gregorianMonth)
        view.addSubview(gregorianDay)
        view.addSubview(gregorianDayField)
        
        view.addSubview(separator1)
        
        view.addSubview(jalaliLabel)
        view.addSubview(jalaliYear)
        view.addSubview(jalaliYearField)
        view.addSubview(jalaliMonth)
        view.addSubview(jalaliDay)
        view.addSubview(jalaliDayField)
        
        view.addSubview(separator2)
        
        view.addSubview(islamicLabel)
        view.addSubview(islamicYear)
        view.addSubview(islamicYearField)
        view.addSubview(islamicMonth)
        view.addSubview(islamicDay)
        view.addSubview(islamicDayField)
        
        view.addSubview(summaryLabel)
        view.addSubview(prevButton)
        view.addSubview(todayButton)
        view.addSubview(nextButton)
        view.addSubview(closeButton)
    }
    
    private func setupConstraints() {
        // Create stacks for year and day with their text fields
        let gregorianYearStack = NSStackView(views: [gregorianYearField, gregorianYear])
        let gregorianDayStack = NSStackView(views: [gregorianDayField, gregorianDay])
        let jalaliYearStack = NSStackView(views: [jalaliYearField, jalaliYear])
        let jalaliDayStack = NSStackView(views: [jalaliDayField, jalaliDay])
        let islamicYearStack = NSStackView(views: [islamicYearField, islamicYear])
        let islamicDayStack = NSStackView(views: [islamicDayField, islamicDay])
        
        [gregorianYearStack, gregorianDayStack, jalaliYearStack, jalaliDayStack, islamicYearStack, islamicDayStack].forEach {
            $0.orientation = .horizontal
            $0.spacing = 5
            $0.alignment = .centerY
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        let gregorianInputStack = NSStackView(views: [gregorianYearStack, gregorianMonth, gregorianDayStack])
        let jalaliInputStack = NSStackView(views: [jalaliYearStack, jalaliMonth, jalaliDayStack])
        let islamicInputStack = NSStackView(views: [islamicYearStack, islamicMonth, islamicDayStack])
        
        [gregorianInputStack, jalaliInputStack, islamicInputStack].forEach {
            $0.orientation = .horizontal
            $0.spacing = 10
            $0.alignment = .centerY
            $0.distribution = .fill
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        let buttonStack = NSStackView(views: [prevButton, todayButton, nextButton, closeButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        let mainStack = NSStackView(views: [
            gregorianLabel,
            gregorianInputStack,
            separator1,
            jalaliLabel,
            jalaliInputStack,
            separator2,
            islamicLabel,
            islamicInputStack
        ])
        mainStack.orientation = .vertical
        mainStack.spacing = 10
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Add all subviews to the view hierarchy before activating constraints
        view.addSubview(mainStack)
        view.addSubview(summaryLabel)
        view.addSubview(buttonStack)
        
        // Now activate constraints
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            
            gregorianYearField.widthAnchor.constraint(equalToConstant: 60),
            gregorianDayField.widthAnchor.constraint(equalToConstant: 40),
            jalaliYearField.widthAnchor.constraint(equalToConstant: 60),
            jalaliDayField.widthAnchor.constraint(equalToConstant: 40),
            islamicYearField.widthAnchor.constraint(equalToConstant: 60),
            islamicDayField.widthAnchor.constraint(equalToConstant: 40),
            
            separator1.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            separator1.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            separator2.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            separator2.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            summaryLabel.topAnchor.constraint(equalTo: mainStack.bottomAnchor, constant: 20),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            buttonStack.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 10),
            buttonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonStack.widthAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    @objc private func previousDate() {
        guard let currentDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: Int(gregorianYear.intValue), month: gregorianMonth.indexOfSelectedItem + 1, day: Int(gregorianDay.intValue))) else { return }
        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) {
            updateFields(from: newDate, calendar: .current)
        }
    }

    @objc private func nextDate() {
        guard let currentDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: Int(gregorianYear.intValue), month: gregorianMonth.indexOfSelectedItem + 1, day: Int(gregorianDay.intValue))) else { return }
        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) {
            updateFields(from: newDate, calendar: .current)
        }
    }
    
    @objc private func closeWindow() {
        view.window?.close()
    }
    
    @objc private func stepperDidChange(_ sender: NSStepper) {
        // Update the corresponding text field
        if sender == gregorianYear {
            gregorianYearField.stringValue = "\(Int(gregorianYear.intValue))"
            lastEditedCalendar = "gregorian"
        } else if sender == gregorianDay {
            gregorianDayField.stringValue = "\(Int(gregorianDay.intValue))"
            lastEditedCalendar = "gregorian"
        } else if sender == jalaliYear {
            jalaliYearField.stringValue = "\(Int(jalaliYear.intValue))"
            lastEditedCalendar = "jalali"
        } else if sender == jalaliDay {
            jalaliDayField.stringValue = "\(Int(jalaliDay.intValue))"
            lastEditedCalendar = "jalali"
        } else if sender == islamicYear {
            islamicYearField.stringValue = "\(Int(islamicYear.intValue))"
            lastEditedCalendar = "islamic"
        } else if sender == islamicDay {
            islamicDayField.stringValue = "\(Int(islamicDay.intValue))"
            lastEditedCalendar = "islamic"
        }
        updateDateFromFields()
    }
    
    private func setupCalendars() {
        let gregorianMonths = ["January", "February", "March", "April", "May", "June",
                              "July", "August", "September", "October", "November", "December"]
        gregorianMonth.addItems(withTitles: gregorianMonths)
        
        let jalaliMonths = ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
                           "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]
        jalaliMonth.addItems(withTitles: jalaliMonths)
        
        let islamicMonths = ["محرم", "صفر", "ربیع‌الاول", "ربیع‌الثانی", "جمادی‌الاول", "جمادی‌الثانی",
                            "رجب", "شعبان", "رمضان", "شوال", "ذی‌القعده", "ذی‌الحجه"]
        islamicMonth.addItems(withTitles: islamicMonths)
        
        let currentDate = Date()
        updateFields(from: currentDate, calendar: .current)
    }
    
    private func setupBindings() {
        gregorianMonth.target = self
        gregorianMonth.action = #selector(fieldDidChange)
        gregorianMonth.isEnabled = true
        
        jalaliMonth.target = self
        jalaliMonth.action = #selector(fieldDidChange)
        jalaliMonth.isEnabled = true
        
        islamicMonth.target = self
        islamicMonth.action = #selector(fieldDidChange)
        islamicMonth.isEnabled = true
    }
    
    @objc private func setToday() {
        let currentDate = Date()
        updateFields(from: currentDate, calendar: .current)
    }
    
    @objc private func fieldDidChange(_ sender: Any) {
        updateDateFromFields()
    }
    
    private func updateDateFromFields() {
        var components = DateComponents()
        var calendar: Calendar
        
        switch lastEditedCalendar {
        case "gregorian":
            calendar = Calendar(identifier: .gregorian)
            components.year = Int(gregorianYear.intValue)
            components.month = gregorianMonth.indexOfSelectedItem + 1
            components.day = Int(gregorianDay.intValue)
        case "jalali":
            calendar = Calendar(identifier: .persian)
            components.year = Int(jalaliYear.intValue)
            components.month = jalaliMonth.indexOfSelectedItem + 1
            components.day = Int(jalaliDay.intValue)
        case "islamic":
            calendar = Calendar(identifier: .islamic)
            components.year = Int(islamicYear.intValue)
            components.month = islamicMonth.indexOfSelectedItem + 1
            components.day = Int(islamicDay.intValue)
        default:
            return
        }
        
        if components.year == nil || components.month == nil || components.day == nil {
            print("Invalid date components: \(components)")
            return
        }
        
        if let date = calendar.date(from: components) {
            updateFields(from: date, calendar: calendar)
        } else {
            print("Failed to create date from components: \(components)")
        }
    }
    
    private func updateFields(from date: Date, calendar: Calendar) {
        let gregorianCal = Calendar(identifier: .gregorian)
        let jalaliCal = Calendar(identifier: .persian)
        let islamicCal = Calendar(identifier: .islamic)
        
        // Update Gregorian
        let gregorianComponents = gregorianCal.dateComponents([.year, .month, .day], from: date)
        gregorianYear.intValue = Int32(gregorianComponents.year ?? 0)
        gregorianYearField.stringValue = "\(gregorianComponents.year ?? 0)"
        gregorianMonth.selectItem(at: (gregorianComponents.month ?? 1) - 1)
        gregorianDay.intValue = Int32(gregorianComponents.day ?? 0)
        gregorianDayField.stringValue = "\(gregorianComponents.day ?? 0)"
        
        // Update Jalali
        let jalaliComponents = jalaliCal.dateComponents([.year, .month, .day], from: date)
        jalaliYear.intValue = Int32(jalaliComponents.year ?? 0)
        jalaliYearField.stringValue = "\(jalaliComponents.year ?? 0)"
        jalaliMonth.selectItem(at: (jalaliComponents.month ?? 1) - 1)
        jalaliDay.intValue = Int32(jalaliComponents.day ?? 0)
        jalaliDayField.stringValue = "\(jalaliComponents.day ?? 0)"
        
        // Update Islamic with offset
        let adjustedDate = Calendar.current.date(byAdding: .day, value: islamicDateOffset, to: date) ?? date
        let islamicComponents = islamicCal.dateComponents([.year, .month, .day], from: adjustedDate)
        islamicYear.intValue = Int32(islamicComponents.year ?? 0)
        islamicYearField.stringValue = "\(islamicComponents.year ?? 0)"
        islamicMonth.selectItem(at: (islamicComponents.month ?? 1) - 1)
        islamicDay.intValue = Int32(islamicComponents.day ?? 0)
        islamicDayField.stringValue = "\(islamicComponents.day ?? 0)"
        
        // Update summary
        let gregorianStr = "\(gregorianYear.intValue)-\(String(format: "%02d", gregorianMonth.indexOfSelectedItem + 1))-\(gregorianDay.intValue)"
        let jalaliStr = "\(jalaliYear.intValue)-\(String(format: "%02d", jalaliMonth.indexOfSelectedItem + 1))-\(jalaliDay.intValue)"
        let islamicStr = "\(islamicYear.intValue)-\(String(format: "%02d", islamicMonth.indexOfSelectedItem + 1))-\(islamicDay.intValue)"
        summaryLabel.stringValue = "Gregorian: \(gregorianStr)\nJalali: \(jalaliStr)\nIslamic: \(islamicStr)"
    }
}


class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var islamicDateOffset: Int {
        get {
            UserDefaults.standard.integer(forKey: "IslamicDateOffset")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "IslamicDateOffset")
        }
    }
    
    private var dateConverterWindowController: DateConverterWindowController?
    var dateConverterMenuItem: NSMenuItem?
    var statusItem: NSStatusItem?
    var jalaliDateItem: NSMenuItem?
    var arabicDateItem: NSMenuItem?
    var gregorianDateItem: NSMenuItem?
    var gePersian: NSMenuItem?
    
    let data = [
        ["1", "January", "محرم", "فروردین", "۱"],
        ["2", "February", "صفر", "اردیبهشت", "۲"],
        ["3", "March", "ربیع‌الاول", "خرداد", "۳"],
        ["4", "April", "ربیع‌الثانی", "تیر", "۴"],
        ["5", "May", "جمادی‌الاول", "مرداد", "۵"],
        ["6", "June", "جمادی‌الثانی", "شهریور", "۶"],
        ["7", "July", "رجب", "مهر", "۷"],
        ["8", "August", "شعبان", "آبان", "۸"],
        ["9", "September", "رمضان", "آذر", "۹"],
        ["10", "October", "شوال", "دی", "۱۰"],
        ["11", "November", "ذی‌القعده", "بهمن", "۱۱"],
        ["12", "December", "ذی‌الحجه", "اسفند", "۱۲"]
    ]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
        requestNotificationPermission()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        
        let menu = NSMenu()
        
        jalaliDateItem = NSMenuItem(title: "loading ...", action: #selector(copyJalaliDate), keyEquivalent: "c")
        jalaliDateItem!.image = NSImage(systemSymbolName: "j.circle.fill", accessibilityDescription: "Jalali Date")
        menu.addItem(jalaliDateItem!)
        
        gregorianDateItem = NSMenuItem(title: "loading ...", action: #selector(copyGregorianDate), keyEquivalent: "x")
        gregorianDateItem!.image = NSImage(systemSymbolName: "g.circle.fill", accessibilityDescription: "Gregorian Date")
        menu.addItem(gregorianDateItem!)
        
        arabicDateItem = NSMenuItem(title: "loading ...", action: #selector(copyArabicDate), keyEquivalent: "a")
        arabicDateItem!.image = NSImage(systemSymbolName: "a.circle.fill", accessibilityDescription: "Arabic Date")
        menu.addItem(arabicDateItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        gePersian = NSMenuItem(title: "loading ...", action: #selector(copyVersionDate), keyEquivalent: "d")
        gePersian!.image = NSImage(systemSymbolName: "calendar.circle.fill", accessibilityDescription: "Version Date")
        menu.addItem(gePersian!)
        
        menu.addItem(NSMenuItem.separator())
        
        let gmItem = NSMenuItem(title: "Months Table", action: #selector(showMonthTableAlert), keyEquivalent: "")
        gmItem.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Months Table Icon")
        menu.addItem(gmItem)
        
        let dateConverterMenuItem = NSMenuItem(title: "Date Convert", action: #selector(showDateConvert(_:)), keyEquivalent: "")
        dateConverterMenuItem.image = NSImage(systemSymbolName: "rectangle.landscape.rotate", accessibilityDescription: "Date Converter Icon")
        dateConverterMenuItem.isEnabled = true
        dateConverterMenuItem.target = self
        self.dateConverterMenuItem = dateConverterMenuItem
        menu.addItem(dateConverterMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "About Jalali Date v5", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About Icon")
        menu.addItem(aboutItem)
        
        let siteItem = NSMenuItem(title: "BlackSwanDev.com", action: #selector(openSite), keyEquivalent: "")
        siteItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Site Icon")
        menu.addItem(siteItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let offsetSettingsItem = NSMenuItem(title: "Setting", action: #selector(showIslamicOffsetSettings), keyEquivalent: "")
        offsetSettingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Setting Icon")
        menu.addItem(offsetSettingsItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit Icon")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        updateTaskbarTitle()
        updateIcon()
        
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.updateIcon()
        }
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.updateTaskbarTitle()
        }
        
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(showMenu)
    }
    
    @objc func showDateConvert(_ sender: Any?) {
        if dateConverterWindowController == nil {
            dateConverterWindowController = DateConverterWindowController(statusItem: statusItem)
            
            dateConverterMenuItem?.isEnabled = false
            print("Menu item disabled: \(dateConverterMenuItem?.isEnabled ?? false)")
        }
        
        dateConverterWindowController?.showWindow(nil)
        dateConverterWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: dateConverterWindowController?.window,
            queue: nil
        ) { [weak self] _ in
            self?.dateConverterWindowController = nil
            self?.dateConverterMenuItem?.isEnabled = true
            print("Menu item enabled: \(self?.dateConverterMenuItem?.isEnabled ?? false)")
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: "")
        cell.isBordered = false
        cell.backgroundColor = .clear
        cell.alignment = .center
        
        if let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn!) {
            cell.stringValue = data[row][columnIndex]
        }
        
        return cell
    }
    
    func updateIcon() {
        let day = getCurrentJalaliDay()
        statusItem?.button?.image = generateIcon(with: "\(day)")
        jalaliDateItem?.title = "\(getJalaliDateString()) | \(getCurrentJalaliDate2())"
        arabicDateItem?.title = "\(getArabicDateString()) | \(getCurrentArabicDate2())"
        gregorianDateItem?.title = "\(getCurrentGregorianDate()) | \(getGregorianDateString())"
        gePersian?.title = "Copy version dates"
    }
    
    @objc func showIslamicOffsetSettings() {
        let alert = NSAlert()
        alert.messageText = "Islamic Date Offset"
        alert.informativeText = "In order to Adjust Islamic (Arabic / Hijri) Date Offset, choose a value between -4 to +4 day, and Save"
        
        let dropdown = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        for offset in -4...4 {
            dropdown.addItem(withTitle: "\(offset)")
        }
        dropdown.selectItem(withTitle: "\(islamicDateOffset)")
        alert.accessoryView = dropdown
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let selectedTitle = dropdown.selectedItem?.title, let newOffset = Int(selectedTitle) {
                islamicDateOffset = newOffset
                updateIcon()
            }
        }
    }
    
    func updateTaskbarTitle() {
        statusItem?.button?.title = ""
    }
    
    @objc func showCopyNotification(message: String) {
        statusItem?.button?.image = generateIcon(with: "✓")
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            self.updateIcon()
        }
    }
    
    @objc func showMenu() {
        NSApp.activate(ignoringOtherApps: true)
        statusItem?.menu?.popUp(positioning: nil, at: .zero, in: statusItem?.button)
    }
    
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
        showCopyNotification(message: "Version Date copied Successfully")
    }
    
    @objc func copyArabicDate() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(getCurrentArabicDate())", forType: .string)
        showCopyNotification(message: "Islamic Date Copied: \(getCurrentArabicDate())")
    }
    
    @objc func showMonthTableAlert() {
        let alert = NSAlert()
        alert.messageText = "Calendars Months name Table"
        alert.alertStyle = .informational
        
        let tableView = NSTableView()
        tableView.rowSizeStyle = .medium
        tableView.headerView = nil
        
        let columns = [
            ("Number", "number", 40.0),
            ("Gregorian", "gregorian", 80.0),
            ("Islamic (Hijri)", "jalali", 80.0),
            ("Jalali (Persian)", "jalali", 80.0),
            ("Number", "number", 40.0),
        ]
        
        for (title, identifier, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            tableView.addTableColumn(column)
        }
        
        tableView.dataSource = self
        tableView.delegate = self
        
        let tableHeight = CGFloat(data.count) * tableView.rowHeight
        tableView.frame = NSRect(x: 0, y: 0, width: 380, height: tableHeight)
        
        alert.accessoryView = tableView
        
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        alert.runModal()
    }
    
    @objc func copyGregorianDate() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(getCurrentGregorianDate(), forType: .string)
        showCopyNotification(message: "Gregorian Date Copied: \(getCurrentGregorianDate())")
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About JalaliDate-Toolbar"
        alert.informativeText = """
        Version 5.0 | 2025-03-23 | 1404-01-03

        This macOS menu bar app shows the current Jalali date directly in the menu bar icon. With a simple click, it reveals today’s date in Persian (Jalali), Islamic (Hijri), and Gregorian calendars. You can fine-tune the Hijri date offset, browse a comprehensive month names table across all calendars, and quickly copy the date in your preferred format — all in a clean, minimal interface.
        """
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Amirhp.Com")
        alert.addButton(withTitle: "BlackSwanDev.Com")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://amirhp.com") {
                NSWorkspace.shared.open(url)
            }
        }
        if response == .alertThirdButtonReturn {
            if let url = URL(string: "https://blackswandev.com") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc func openLink(_ sender: NSTextField) {
        if let link = sender.attributedStringValue.attribute(.link, at: 0, effectiveRange: nil) as? URL {
            NSWorkspace.shared.open(link)
        }
    }
    
    @objc func openSite() {
        if let url = URL(string: "https://blackswandev.com/") {
            NSWorkspace.shared.open(url)
        }
    }
}

func convertPersianNumbersToEnglish(_ persianString: String) -> String {
    let persianDigits = ["۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
                         "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"]
    var englishString = persianString
    for (persian, english) in persianDigits {
        englishString = englishString.replacingOccurrences(of: persian, with: english)
    }
    return englishString
}

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

func getCurrentArabicDate() -> String {
    let adjustedDate = Calendar.current.date(byAdding: .day, value: islamicDateOffset, to: Date()) ?? Date()
    let calendar = Calendar(identifier: .islamic)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: adjustedDate)
}

func getCurrentArabicDate2() -> String {
    let adjustedDate = Calendar.current.date(byAdding: .day, value: islamicDateOffset, to: Date()) ?? Date()
    let calendar = Calendar(identifier: .islamic)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "dd-MM-yyyy"
    return formatter.string(from: adjustedDate)
}

func getArabicDateString() -> String {
    let persianCalendar = Calendar(identifier: .islamic)
    let formatter = DateFormatter()
    formatter.calendar = persianCalendar
    formatter.locale = Locale(identifier: "fa_IR")
    formatter.dateFormat = "d MMMM"
    let adjustedDate = Calendar.current.date(byAdding: .day, value: islamicDateOffset, to: Date()) ?? Date()
    let persianDateWithPersianNumbers = formatter.string(from: adjustedDate)
    let englishDigitsDate = convertPersianNumbersToEnglish(persianDateWithPersianNumbers)
    let persianCalendar2 = Calendar(identifier: .persian)
    formatter.calendar = persianCalendar2
    formatter.locale = Locale(identifier: "fa_IR")
    formatter.dateFormat = "EEEE"
    let weekday = formatter.string(from: Date())
    return "\(weekday) \(englishDigitsDate)"
}

func getCurrentJalaliDate() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: currentDate)
}

func getCurrentJalaliDate2() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "dd-MM-yyyy"
    return formatter.string(from: currentDate)
}

func getCurrentJalaliDay() -> Int {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    return calendar.component(.day, from: currentDate)
}

func getCurrentJalaliMonthInt() -> Int {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    return calendar.component(.month, from: currentDate)
}

func getCurrentJalaliMonth() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "fa_IR")
    formatter.dateFormat = "MMMM"
    return formatter.string(from: currentDate)
}

func getCurrentJalaliWeekday() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "fa_IR")
    formatter.dateFormat = "EEEE"
    return formatter.string(from: currentDate)
}

func getJalaliDateString() -> String {
    let persianCalendar = Calendar(identifier: .persian)
    let formatter = DateFormatter()
    formatter.calendar = persianCalendar
    formatter.locale = Locale(identifier: "fa_IR")
    formatter.dateFormat = "EEEE d MMMM"
    let persianDateWithPersianNumbers = formatter.string(from: Date())
    let englishDigitsDate = convertPersianNumbersToEnglish(persianDateWithPersianNumbers)
    return englishDigitsDate
}

func getGregorianDateString() -> String {
    let gregorianCalendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = gregorianCalendar
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "EEEE d MMMM"
    let gregorianDate = formatter.string(from: Date())
    return gregorianDate
}

func getCurrentGregorianDate() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: currentDate)
}

func getCurrentGregorianMonth() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "MMMM"
    return formatter.string(from: currentDate)
}

func getCurrentGregorianWeekday() -> String {
    let currentDate = Date()
    let calendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "EEEE"
    return formatter.string(from: currentDate)
}

func isTodayFriday() -> Bool {
    let calendar = Calendar(identifier: .gregorian)
    let today = Date()
    let weekday = calendar.component(.weekday, from: today)
    return weekday == 6
}

func generateIcon(with day: String) -> NSImage {
    let width: CGFloat = 20
    let height: CGFloat = 20
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    
    let borderColor: NSColor = isTodayFriday() ? .red : .yellow
    let textColor: NSColor = .black
    
    let rectPath = NSBezierPath(
        roundedRect: NSRect(x: 1, y: 1, width: width - 2, height: height - 2), xRadius: 10,
        yRadius: 10)
    borderColor.setStroke()
    rectPath.lineWidth = 1.5
    rectPath.stroke()
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10),
        .foregroundColor: textColor,
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
    image.isTemplate = true
    return image
}
