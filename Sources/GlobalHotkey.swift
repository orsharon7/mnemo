import AppKit
import Carbon

final class GlobalHotkey {
    typealias Handler = () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private let signature: OSType = 0x434C4D54 // 'CLMT'
    private let id: UInt32 = 1

    private static var handlers: [UInt32: Handler] = [:]
    private static var eventHandlerInstalled = false

    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) {
        if !GlobalHotkey.eventHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                          eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, _) -> OSStatus in
                guard let eventRef = eventRef else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(eventRef,
                                  EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID),
                                  nil,
                                  MemoryLayout<EventHotKeyID>.size,
                                  nil,
                                  &hkID)
                if let h = GlobalHotkey.handlers[hkID.id] {
                    DispatchQueue.main.async { h() }
                }
                return noErr
            }, 1, &eventType, nil, nil)
            GlobalHotkey.eventHandlerInstalled = true
        }

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        if status != noErr {
            NSLog("Mnemo: hotkey register failed status=\(status)")
            return nil
        }
        GlobalHotkey.handlers[id] = handler
    }

    deinit {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        GlobalHotkey.handlers.removeValue(forKey: id)
    }
}
