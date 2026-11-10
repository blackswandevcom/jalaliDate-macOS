import Carbon.HIToolbox
import Foundation

/// Global hotkeys (Carbon), no Accessibility permission needed.
/// Id 1 opens the popover; the copy actions get their own ids.
final class Hotkey: ObservableObject {
    static let shared = Hotkey()

    /// Opens the popover.
    var action: (() -> Void)?

    /// Shortcuts macOS refused because another app already has them ("popover" or a copy action id).
    @Published private(set) var taken: Set<String> = []

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var tags: [UInt32: String] = [:]
    private var handler: EventHandlerRef?

    private static let popoverID: UInt32 = 1
    private static let copyBaseID: UInt32 = 100

    private static let keyCodes: [String: Int] = [
        "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D, "E": kVK_ANSI_E, "F": kVK_ANSI_F,
        "G": kVK_ANSI_G, "H": kVK_ANSI_H, "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
        "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P, "Q": kVK_ANSI_Q, "R": kVK_ANSI_R,
        "S": kVK_ANSI_S, "T": kVK_ANSI_T, "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
        "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
        "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "Space": kVK_Space,
    ]

    /// Letters, then digits, then Space.
    static var keys: [String] {
        keyCodes.keys.sorted { a, b in
            func rank(_ s: String) -> Int { s.count > 1 ? 2 : (s.first!.isNumber ? 1 : 0) }
            return rank(a) == rank(b) ? a < b : rank(a) < rank(b)
        }
    }

    /// The "open jDate" shortcut.
    func register(_ s: GeneralSettings) {
        remove(Self.popoverID)
        guard s.hotkeyEnabled else { return }
        add(Self.popoverID, s.hotkeyCombo, tag: "popover") { [weak self] in self?.action?() }
    }

    /// The global copy shortcuts.
    func registerCopy(_ list: [(id: String, combo: KeyCombo, run: () -> Void)]) {
        for id in refs.keys where id >= Self.copyBaseID { remove(id) }
        taken = taken.intersection(["popover"])
        for (i, item) in list.enumerated() {
            add(Self.copyBaseID + UInt32(i), item.combo, tag: item.id, run: item.run)
        }
    }

    private func add(_ id: UInt32, _ combo: KeyCombo, tag: String, run: @escaping () -> Void) {
        taken.remove(tag)
        guard combo.isValid, let code = Self.keyCodes[combo.key] else { return }
        var mods: UInt32 = 0
        if combo.control { mods |= UInt32(controlKey) }
        if combo.option { mods |= UInt32(optionKey) }
        if combo.command { mods |= UInt32(cmdKey) }
        if combo.shift { mods |= UInt32(shiftKey) }
        installHandler()

        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x6A44_5445), id: id) // 'jDTE'
        let status = RegisterEventHotKey(UInt32(code), mods, hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[id] = ref
            actions[id] = run
            tags[id] = tag
        } else {
            taken.insert(tag)
        }
    }

    private func remove(_ id: UInt32) {
        if let ref = refs[id] { UnregisterEventHotKey(ref) }
        refs[id] = nil
        actions[id] = nil
        if let tag = tags.removeValue(forKey: id) { taken.remove(tag) }
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }
            var hkID = EventHotKeyID()
            let err = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            guard err == noErr else { return noErr }
            let me = Unmanaged<Hotkey>.fromOpaque(userData).takeUnretainedValue()
            let id = hkID.id
            DispatchQueue.main.async { me.actions[id]?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
}
