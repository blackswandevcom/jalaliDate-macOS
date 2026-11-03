import Cocoa
import Combine
import SwiftUI
import UserNotifications
import WidgetKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate, UNUserNotificationCenterDelegate {
    let model = AppModel()

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var mainWindow: NSWindow?
    private var clockTimer: Timer?
    private var weatherTimer: Timer?
    private var flashUntil: Date?
    private var lastIconKey: String?
    private var lastDayISO = ""
    private var bag = Set<AnyCancellable>()

    private var settings: AppSettings { model.settings }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "jDate"
        }

        let host = NSHostingController(rootView: FontRoot { PopoverView(model: self.model) })
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        // Lets the glass tint reach under the arrow too.
        popover.hasFullSizeContent = true

        model.onCopy = { [weak self] in self?.flashCopied() }
        model.onOpenMain = { [weak self] in self?.showMainWindow() }

        Hotkey.shared.action = { [weak self] in self?.togglePopover() }
        Hotkey.shared.register(settings.general)

        observeSettings()
        tick()
        #if DEBUG
        DistributedNotificationCenter.default().addObserver(forName: .init("blackswan.jdate.debug.toggle"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                // Background apps can't activate themselves, so a transient popover would close at once.
                self?.popover.behavior = .applicationDefined
                self?.togglePopover()
            }
        }
        // Screenshot helper: {"glass": GlassStyle JSON, "widgetGlass": …, "theme": ThemeConfig JSON, "day": offset, "tab": raw}
        DistributedNotificationCenter.default().addObserver(forName: .init("blackswan.jdate.debug.set"), object: nil, queue: .main) { [weak self] n in
            let info = n.userInfo as? [String: String] ?? [:]
            Task { @MainActor in
                guard let self else { return }
                let dec = JSONDecoder()
                if let j = info["glass"]?.data(using: .utf8), let g = try? dec.decode(GlassStyle.self, from: j) { GlassSettings.shared.popover = g }
                if let j = info["widgetGlass"]?.data(using: .utf8), let g = try? dec.decode(GlassStyle.self, from: j) { GlassSettings.shared.widget = g }
                if let j = info["theme"]?.data(using: .utf8), let t = try? dec.decode(ThemeConfig.self, from: j) { self.settings.theme = t }
                if let d = info["day"].flatMap(Int.init) {
                    self.model.selectedDay = Calendar(identifier: .gregorian).date(byAdding: .day, value: d, to: self.model.now) ?? self.model.now
                }
                if let t = info["tab"].flatMap(MainTab.init(rawValue:)) { self.model.open(t) }
                if let m = info["media"], let (name, kind) = try? await HeaderMedia.importFile(URL(fileURLWithPath: m)) {
                    HeaderMedia.remove(self.settings.theme.mediaFile)
                    self.settings.theme.mediaFile = name
                    self.settings.theme.mediaKind = kind
                    self.settings.theme.mode = .media
                }
            }
        }
        #endif

        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        weatherTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshData() }
        }
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
                await self?.refreshData()
            }
        }
        // Hijri offset / variant are plain UserDefaults keys edited from the General page.
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateIcon(force: true) }
        }

        Task {
            await model.events.refreshFeeds()
            await refreshData()
            await Notifier.reschedule(birthdays: model.birthdays, events: model.events)
        }
    }

    private func observeSettings() {
        GlassSettings.shared.$popover.dropFirst().receive(on: RunLoop.main).sink { [weak self] g in
            self?.applyPopoverGlass(g)
        }.store(in: &bag)
        GlassSettings.shared.$widget.dropFirst().debounce(for: .seconds(0.5), scheduler: RunLoop.main).sink { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }.store(in: &bag)
        settings.$theme.dropFirst().debounce(for: .seconds(0.8), scheduler: RunLoop.main).sink { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }.store(in: &bag)
        FontSettings.shared.objectWillChange.debounce(for: .seconds(0.3), scheduler: RunLoop.main).sink { [weak self] _ in
            self?.updateIcon(force: true)
            WidgetCenter.shared.reloadAllTimelines()
        }.store(in: &bag)
        settings.$icon.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updateIcon(force: true)
        }.store(in: &bag)
        settings.$general.dropFirst().receive(on: RunLoop.main).sink { [weak self] g in
            Hotkey.shared.register(g)
            self?.model.events.invalidate()
        }.store(in: &bag)
        settings.$layout.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            let before = Set(model.weather.allCities.map(\.id))
            model.syncWeatherCities()
            if Set(model.weather.allCities.map(\.id)) != before { Task { await self.refreshData() } }
        }.store(in: &bag)
        model.weather.$settings.dropFirst().removeDuplicates().debounce(for: .seconds(0.6), scheduler: RunLoop.main).sink { [weak self] _ in
            Task { await self?.refreshData(force: true) }
        }.store(in: &bag)
        // Events, birthdays and calendars feed the desktop widgets and the reminders.
        model.events.$revision.dropFirst().debounce(for: .seconds(1), scheduler: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            writeWidgetCache()
            Task { await Notifier.reschedule(birthdays: self.model.birthdays, events: self.model.events) }
        }.store(in: &bag)
        model.birthdays.$settings.dropFirst().debounce(for: .seconds(1), scheduler: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            Task { await Notifier.reschedule(birthdays: self.model.birthdays, events: self.model.events) }
        }.store(in: &bag)
    }

    // MARK: Refresh

    private func tick() {
        let now = Date()
        model.now = now
        let iso = CalendarService.iso(now, .gregorian)
        if iso != lastDayISO {
            let first = lastDayISO.isEmpty
            lastDayISO = iso
            if !first {
                model.selectedDay = now
                model.events.invalidate()
                Task { await Notifier.reschedule(birthdays: model.birthdays, events: model.events) }
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
        updateIcon()
    }

    private func refreshData(force: Bool = false) async {
        await model.weather.refresh(force: force)
        writeWidgetCache()
    }

    private func writeWidgetCache() {
        model.events.writeWidgetCache(weather: model.weather)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func updateIcon(force: Bool = false) {
        guard let button = statusItem?.button else { return }
        if let until = flashUntil, until > Date() { return }

        let cfg = settings.icon
        let now = Date()
        let badge = MenubarIcon.badgeText(cfg, date: now)
        let title = MenubarIcon.title(cfg, date: now)
        let key = "\(badge)|\(title.string)|\(CalendarService.islamicOffset)|\(AppFont.signature)"
        if !force && key == lastIconKey { return }
        lastIconKey = key

        switch cfg.layout {
        case .badge:
            button.image = MenubarIcon.badge(badge, config: cfg)
            button.attributedTitle = NSAttributedString()
            button.imagePosition = .imageOnly
        case .text:
            button.image = nil
            button.attributedTitle = title
            button.imagePosition = .noImage
        case .both:
            button.image = MenubarIcon.badge(badge, config: cfg)
            let t = NSMutableAttributedString(string: " ")
            t.append(title)
            button.attributedTitle = t
            button.imagePosition = .imageLeading
        }
        button.toolTip = "\(CalendarService.long(now, .jalali))\n\(CalendarService.long(now, .gregorian))\n\(CalendarService.long(now, .islamic))"
    }

    private func flashCopied() {
        guard let button = statusItem?.button else { return }
        let duration: TimeInterval = 0.8
        flashUntil = Date().addingTimeInterval(duration)
        var cfg = settings.icon
        if cfg.shape == .none { cfg.shape = .circle }
        button.image = MenubarIcon.badge("✓", config: cfg)
        button.attributedTitle = NSAttributedString()
        button.imagePosition = .imageOnly
        Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.flashUntil = nil
                self?.updateIcon(force: true)
            }
        }
    }

    // MARK: Status item & popover

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        togglePopover()
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            tick()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverWillShow(_ notification: Notification) {
        model.popoverVisible = true
        applyPopoverGlass(GlassSettings.shared.popover)
        Task { await refreshData() }   // only fetches cities older than 30 min
    }

    func popoverDidShow(_ notification: Notification) {
        applyPopoverGlass(GlassSettings.shared.popover)
    }

    /// Terminal-style background: the popover's own blur view fades out as the blur goes down,
    /// so the desktop behind shows through sharper. The tint itself is drawn by PopoverView.
    private func applyPopoverGlass(_ glass: GlassStyle) {
        guard let content = popover.contentViewController?.view, let window = content.window,
              let root = window.contentView?.superview ?? window.contentView else { return }
        let alpha = glass.enabled ? CGFloat(max(0, min(1, glass.blur))) : 1
        // macOS 26+ draws the popover with a glass view next to the content; older systems with an
        // NSVisualEffectView. Never fade a view that holds the content, or the content fades too.
        func walk(_ v: NSView) {
            if v === content { return }
            let isBackdrop = v is NSVisualEffectView || NSStringFromClass(type(of: v)).contains("Glass")
            if isBackdrop {
                if content.isDescendant(of: v) { v.alphaValue = 1 } else { v.alphaValue = alpha; return }
            }
            v.subviews.forEach(walk)
        }
        walk(root)
    }

    func popoverDidClose(_ notification: Notification) {
        model.popoverVisible = false
    }

    private func showContextMenu() {
        let menu = NSMenu()
        func item(_ title: String, _ tab: MainTab) {
            let i = NSMenuItem(title: title, action: #selector(openTabFromMenu(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = tab.rawValue
            i.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: nil)
            menu.addItem(i)
        }
        item("Date Converter…", .converter)
        item("Customize Popover…", .layout)
        item("Menubar Icon…", .icon)
        item("Settings…", .general)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit jDate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openTabFromMenu(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let tab = MainTab(rawValue: raw) { model.open(tab) }
    }

    // MARK: Notifications

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            if !self.popover.isShown { self.togglePopover() }
        }
    }

    // MARK: Main window

    private func showMainWindow() {
        popover.performClose(nil)
        if mainWindow == nil {
            let host = NSHostingController(rootView: FontRoot { MainWindowView(model: self.model) })
            host.sceneBridgingOptions = [.toolbars, .title]
            host.sizingOptions = [.minSize]
            let window = NSWindow(contentViewController: host)
            window.title = "jDate"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            // A real toolbar gives the titlebar its height, so the sidebar starts below the
            // traffic lights instead of under them.
            window.toolbar = NSToolbar(identifier: "jDateMainToolbar")
            window.toolbarStyle = .unified
            // Never let the window be narrower than the SwiftUI content, or the content
            // overflows and gets clipped on the left.
            window.contentMinSize = NSSize(width: 860, height: 580)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setFrameAutosaveName("jDateMainWindow3")
            if window.frame.width < 860 || window.frame.height < 580 {
                window.setContentSize(NSSize(width: 920, height: 640))
                window.center()
            }
            mainWindow = window
        }
        // Show in the Dock / ⌘-Tab while the window is open, so it can take focus.
        NSApp.setActivationPolicy(.regular)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === mainWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }
}
