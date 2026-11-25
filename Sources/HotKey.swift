import Carbon.HIToolbox

/// System-wide hotkey via Carbon. Needs no Accessibility permission.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().action()
                return noErr
            },
            1, &eventType, selfPtr, &handlerRef
        )

        let id = EventHotKeyID(signature: 0x544D_5452, id: 1) // 'TMTR'
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    /// ⌃⌥P
    static let defaultKeyCode = UInt32(kVK_ANSI_P)
    static let defaultModifiers = UInt32(controlKey | optionKey)
}
