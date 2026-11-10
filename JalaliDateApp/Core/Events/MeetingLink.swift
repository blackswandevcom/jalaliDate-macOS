import EventKit
import Foundation

/// Finds the video-call link of a calendar event (Google Meet, Zoom, Teams, Webex, FaceTime…).
enum MeetingLink {
    struct Service { let host: String; let name: String }

    static let services: [Service] = [
        Service(host: "meet.google.com", name: "Google Meet"),
        Service(host: "zoom.us", name: "Zoom"),
        Service(host: "zoom.com", name: "Zoom"),
        Service(host: "zoomgov.com", name: "Zoom"),
        Service(host: "teams.microsoft.com", name: "Microsoft Teams"),
        Service(host: "teams.live.com", name: "Microsoft Teams"),
        Service(host: "webex.com", name: "Webex"),
        Service(host: "facetime.apple.com", name: "FaceTime"),
        Service(host: "whereby.com", name: "Whereby"),
        Service(host: "meet.jit.si", name: "Jitsi Meet"),
        Service(host: "chime.aws", name: "Amazon Chime"),
        Service(host: "gotomeeting.com", name: "GoTo Meeting"),
        Service(host: "meet.goto.com", name: "GoTo Meeting"),
        Service(host: "join.skype.com", name: "Skype"),
        Service(host: "bluejeans.com", name: "BlueJeans"),
        Service(host: "skyroom.online", name: "Skyroom"),
        Service(host: "discord.gg", name: "Discord"),
        Service(host: "slack.com", name: "Slack huddle"),
    ]

    private static let schemes = ["zoommtg", "zoomus", "msteams", "facetime"]

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// The service a URL belongs to, if it is a meeting link.
    static func service(of url: URL) -> Service? {
        guard let host = url.host?.lowercased() else { return nil }
        let match = services.first { host == $0.host || host.hasSuffix("." + $0.host) }
        // Slack links are only meetings when they are huddles.
        if match?.host == "slack.com", !url.absoluteString.contains("huddle") { return nil }
        return match
    }

    static func isMeeting(_ url: URL) -> Bool {
        if let s = url.scheme?.lowercased(), schemes.contains(s) { return true }
        return service(of: url) != nil
    }

    static func find(in event: EKEvent) -> URL? {
        if let url = event.url, isMeeting(url) { return url }
        return find(in: [event.location, event.notes].compactMap { $0 }.joined(separator: "\n"))
    }

    static func find(in text: String) -> URL? {
        guard !text.isEmpty, let detector else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for m in detector.matches(in: text, range: range) {
            if let url = m.url, isMeeting(url) { return url }
        }
        return nil
    }

    /// "Google Meet", "Zoom"… for the tooltip.
    static func name(of url: URL) -> String {
        if let s = service(of: url) { return s.name }
        switch url.scheme?.lowercased() {
        case "zoommtg", "zoomus": return "Zoom"
        case "msteams": return "Microsoft Teams"
        case "facetime": return "FaceTime"
        default: return url.host ?? "meeting"
        }
    }
}
