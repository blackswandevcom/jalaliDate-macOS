import Foundation
#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

/// Settings shared by the app and the desktop widgets (App Group).
enum Prefs {
    static let appGroup = "DFDRW6TJH5.blackswan.jdate"
    static let defaults: UserDefaults = UserDefaults(suiteName: appGroup) ?? .standard

    // Keys
    static let islamicOffsetKey = "IslamicDateOffset"   // same key as v1–v7
    static let hijriVariantKey = "HijriVariant"
    static let legacyIconStyleKey = "MenubarIconStyle"  // v7
    static let iconConfigKey = "IconConfig"
    static let themeKey = "ThemeConfig"
    static let layoutKey = "PopoverLayout"
    static let generalKey = "GeneralSettings"
    static let eventSettingsKey = "EventSettings"
    static let birthdaysKey = "Birthdays"
    static let birthdaySettingsKey = "BirthdaySettings"
    static let weatherSettingsKey = "WeatherSettings"

    /// Copies v1–v7 values from the old non-shared defaults once.
    static func migrate() {
        for key in [islamicOffsetKey, legacyIconStyleKey] where defaults.object(forKey: key) == nil {
            if let value = UserDefaults.standard.object(forKey: key) { defaults.set(value, forKey: key) }
        }
    }

    static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    /// Folder shared with the widgets (falls back to Application Support).
    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return url
        }
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("jDate", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

enum HijriVariant: String, Codable, CaseIterable, Identifiable {
    case islamic, civil, ummAlQura
    var id: String { rawValue }

    var identifier: Calendar.Identifier {
        switch self {
        case .islamic: return .islamic
        case .civil: return .islamicCivil
        case .ummAlQura: return .islamicUmmAlQura
        }
    }

    var title: String {
        switch self {
        case .islamic: return "Islamic (astronomical)"
        case .civil: return "Islamic civil (tabular)"
        case .ummAlQura: return "Umm al-Qura"
        }
    }

    static var current: HijriVariant {
        HijriVariant(rawValue: Prefs.defaults.string(forKey: Prefs.hijriVariantKey) ?? "") ?? .islamic
    }
}

// MARK: - Colors

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt64(s, radix: 16) ?? 0xF97316
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: 1)
    }

    var hexString: String {
        #if canImport(AppKit)
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .orange
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
        #else
        return "#F97316"
        #endif
    }
}
