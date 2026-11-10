import Foundation
import SwiftUI

/// A key plus modifiers, for global (system-wide) shortcuts.
struct KeyCombo: Codable, Equatable, Hashable {
    var key = ""
    var control = true
    var option = true
    var command = false
    var shift = false

    var hasModifier: Bool { control || option || command || shift }
    var isValid: Bool { !key.isEmpty && hasModifier }

    var description: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + key
    }
}

/// One thing jDate can copy: a calendar's date, the version-dates line, or a date in the user's own format.
struct CopyAction: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case jalali, gregorian, islamic, versionDates, custom
    }

    var id: String
    var kind: Kind
    var name: String
    /// Token template (see `DateTokens`), only for `.custom`.
    var pattern = ""
    var persianDigits = false
    /// ⌘ + this key inside the popover; empty = none.
    var popoverKey = ""
    var globalEnabled = false
    var global = KeyCombo()

    var calendar: CalendarKind? {
        switch kind {
        case .jalali: return .jalali
        case .gregorian: return .gregorian
        case .islamic: return .islamic
        default: return nil
        }
    }

    var isBuiltIn: Bool { kind != .custom }

    var symbol: String {
        switch kind {
        case .jalali, .gregorian, .islamic: return calendar!.symbol
        case .versionDates: return "doc.on.clipboard"
        case .custom: return "text.badge.plus"
        }
    }

    /// "⌘C", or nil when it has no popover key.
    var popoverHint: String? { popoverKey.isEmpty ? nil : "⌘" + popoverKey.uppercased() }

    /// Key used by `AppModel.copiedKey`, so the matching tile shows its ✓.
    var copiedKey: String {
        switch kind {
        case .jalali, .gregorian, .islamic: return "date-\(calendar!.rawValue)"
        case .versionDates: return "version"
        case .custom: return "copy-\(id)"
        }
    }

    func text(for date: Date, format: CopyFormat) -> String {
        switch kind {
        case .jalali, .gregorian, .islamic:
            return format.string(date, calendar!)
        case .versionDates:
            return "\(CalendarService.iso(date, .gregorian)) | \(CalendarService.iso(date, .jalali))"
        case .custom:
            return DateTokens.format(pattern, date: date, persianDigits: persianDigits)
        }
    }

    static func newCustom(pattern: String = "{jy}/{jmm}/{jdd}") -> CopyAction {
        CopyAction(id: UUID().uuidString, kind: .custom, name: "My format", pattern: pattern)
    }
}

struct CopySettings: Codable, Equatable {
    /// Show "⌘C" etc. on the date tiles and a row with the other copy shortcuts.
    var showHints = true
    var actions: [CopyAction] = CopySettings.builtIns

    static let builtIns: [CopyAction] = [
        CopyAction(id: "jalali", kind: .jalali, name: "Jalali date", popoverKey: "C", global: KeyCombo(key: "C", command: true)),
        CopyAction(id: "gregorian", kind: .gregorian, name: "Gregorian date", popoverKey: "X", global: KeyCombo(key: "X", command: true)),
        CopyAction(id: "islamic", kind: .islamic, name: "Hijri date", popoverKey: "A", global: KeyCombo(key: "A", command: true)),
        CopyAction(id: "version", kind: .versionDates, name: "Version dates", popoverKey: "D", global: KeyCombo(key: "D", command: true)),
    ]

    /// Keys the popover already uses for something else.
    static let reservedPopoverKeys: [String: String] = ["E": "Date Converter", "Q": "Quit", "W": "Close", "V": "Paste", "Z": "Undo"]

    static let popoverKeys: [String] = (65...90).map { String(UnicodeScalar($0)!) } + (0...9).map(String.init)

    func action(for kind: CalendarKind) -> CopyAction? {
        actions.first { $0.calendar == kind }
    }

    /// Why this action's popover key can't be used, if it can't.
    func popoverConflict(_ a: CopyAction) -> String? {
        guard !a.popoverKey.isEmpty else { return nil }
        if let what = Self.reservedPopoverKeys[a.popoverKey] { return "⌘\(a.popoverKey) is \(what)" }
        if let other = actions.first(where: { $0.id != a.id && $0.popoverKey == a.popoverKey }) {
            return "Also used by \(other.name)"
        }
        return nil
    }

    func globalConflict(_ a: CopyAction, popover: GeneralSettings) -> String? {
        guard a.globalEnabled else { return nil }
        if !a.global.isValid { return "Pick a key and at least one modifier" }
        if popover.hotkeyEnabled, popover.hotkeyCombo == a.global { return "Same as the Open jDate shortcut" }
        if let other = actions.first(where: { $0.id != a.id && $0.globalEnabled && $0.global == a.global }) {
            return "Also used by \(other.name)"
        }
        return nil
    }

    /// Copy settings saved before 8.5 keep working: missing built-ins are added back.
    mutating func ensureBuiltIns() {
        for b in Self.builtIns where !actions.contains(where: { $0.kind == b.kind }) {
            actions.insert(b, at: min(actions.count, Self.builtIns.firstIndex(of: b) ?? 0))
        }
    }
}

extension GeneralSettings {
    var hotkeyCombo: KeyCombo {
        KeyCombo(key: hotkeyKey, control: hotkeyControl, option: hotkeyOption, command: hotkeyCommand, shift: hotkeyShift)
    }
}
