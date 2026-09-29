import AppKit
import ApplicationServices

// Dev-only driver for scripts/e2e-app.py.
//   ETDriver set-cursor N     put the caret at UTF-16 offset N in the focused text field
//   ETDriver get-text         print the focused text field's value
//   ETDriver dictate FILE     ask the dev app (-debugDictationHook) to dictate FILE; waits until done

// Same lookup as CursorContextService.focusedElement.
func focusedElement() -> AXUIElement? {
    func focused(in container: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(container, kAXFocusedUIElementAttribute as CFString, &ref) == .success,
              let ref else { return nil }
        return (ref as! AXUIElement)
    }
    if let element = focused(in: AXUIElementCreateSystemWide()) { return element }
    guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
    return focused(in: AXUIElementCreateApplication(pid))
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "set-cursor":
    guard let element = focusedElement(), let offset = Int(args[2]) else { fail("no focused element") }
    var range = CFRange(location: offset, length: 0)
    let value = AXValueCreate(.cfRange, &range)!
    guard AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success else {
        fail("could not set cursor")
    }
case "get-text":
    guard let element = focusedElement() else { fail("no focused element") }
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &ref)
    print((ref as? String) ?? "", terminator: "")
case "dictate":
    let center = DistributedNotificationCenter.default()
    var done = false
    center.addObserver(forName: Notification.Name("com.embervista.EmberType.debug.dictateFileDone"), object: nil, queue: .main) { _ in
        done = true
    }
    center.postNotificationName(Notification.Name("com.embervista.EmberType.debug.dictateFile"),
                                object: args[2], userInfo: nil, deliverImmediately: true)
    let deadline = Date().addingTimeInterval(60)
    while !done && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
    if !done { fail("timed out waiting for the dev app") }
default:
    fail("usage: ETDriver set-cursor N | get-text | dictate FILE")
}
