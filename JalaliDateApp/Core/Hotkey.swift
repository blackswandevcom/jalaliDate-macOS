import Carbon.HIToolbox
import Foundation

/// One global hotkey (Carbon), no Accessibility permission needed.
final class Hotkey {
    static let shared = Hotkey()

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    private static let keyCodes: [String: Int] = [
        "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D, "E": kVK_ANSI_E, "F": kVK_ANSI_F,
        "G": kVK_ANSI_G, "H": kVK_ANSI_H, "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
        "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P, "Q": kVK_ANSI_Q, "R": kVK_ANSI_R,
        "S": kVK_ANSI_S, "T": kVK_ANSI_T, "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
        "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z, "Space": kVK_Space,
    ]
    static var keys: [String] { keyCodes.keys.sorted { $0.count == $1.count ? $0 < $1 : $0.count < $1.count } }

    func register(_ s: GeneralSettings) {
        unregister()
        guard s.hotkeyEnabled, let code = Self.keyCodes[s.hotkeyKey] else { return }
        var mods: UInt32 = 0
        if s.hotkeyControl { mods |= UInt32(controlKey) }
        if s.hotkeyOption { mods |= UInt32(optionKey) }
        if s.hotkeyCommand { mods |= UInt32(cmdKey) }
        if s.hotkeyShift { mods |= UInt32(shiftKey) }
        guard mods != 0 else { return }

        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
                guard let userData else { return noErr }
                let me = Unmanaged<Hotkey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { me.action?() }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        let id = EventHotKeyID(signature: OSType(0x6A44_5445), id: 1) // 'jDTE'
        RegisterEventHotKey(UInt32(code), mods, id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}
