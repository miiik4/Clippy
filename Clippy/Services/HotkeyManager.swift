import Carbon.HIToolbox
import AppKit

// Global callback for Carbon event handler — must be nonisolated and non-capturing
nonisolated private func hotkeyEventHandler(
    _: EventHandlerCallRef?,
    _: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let context = Unmanaged<HotkeyContext>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        context.action()
    }
    return noErr
}

// Reference type to hold the callback action, passable through C void pointer
private final class HotkeyContext: @unchecked Sendable {
    let action: @Sendable () -> Void
    init(action: @escaping @Sendable () -> Void) {
        self.action = action
    }
}

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var context: HotkeyContext?
    var onHotkey: (() -> Void)?

    func register(keyCode: Int? = nil, modifiers: Int? = nil) {
        unregister()

        let ctx = HotkeyContext { [weak self] in
            self?.onHotkey?()
        }
        self.context = ctx

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(ctx).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        let settings = AppSettings.shared
        let kCode = keyCode ?? settings.hotkeyCode
        let mods = modifiers ?? settings.hotkeyModifiers

        // Hotkey signature: "CLPY"
        let hotKeyID = EventHotKeyID(signature: 0x434C5059, id: 1)

        RegisterEventHotKey(
            UInt32(kCode),
            UInt32(mods),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
        context = nil
    }

    deinit {
        unregister()
    }
}
