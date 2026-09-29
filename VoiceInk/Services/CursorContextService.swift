import Foundation
import AppKit
import ApplicationServices

/// Reads the text just before the insertion point of the focused text field,
/// via Accessibility. Used by spoken punctuation mode to decide whether the
/// dictated text starts a new sentence.
struct CursorContextService {
    enum Position: Equatable {
        case sentenceStart // empty field, or after . ? ! or a line break
        case midSentence
        case unknown       // app doesn't expose its text (many web and Electron apps)
    }

    static func position(after textBeforeCursor: String?) -> Position {
        guard let textBeforeCursor else { return .unknown }
        let trimmed = textBeforeCursor.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        guard let last = trimmed.last else { return .sentenceStart }
        if last.isNewline || ".?!".contains(last) { return .sentenceStart }
        // A closing quote or bracket after a sentence end: `He said "Hi." |`
        if "\"”’)".contains(last), let prev = trimmed.dropLast().last, ".?!".contains(prev) {
            return .sentenceStart
        }
        return .midSentence
    }

    /// True when pasting `text` right after `textBeforeCursor` would glue two
    /// words together ("this|" + "short" → "thisshort").
    static func needsLeadingSpace(before textBeforeCursor: String?, text: String) -> Bool {
        guard let last = textBeforeCursor?.last, !last.isWhitespace, !"(\"“‘".contains(last),
              let first = text.first, !first.isWhitespace, !".,?!;:)…\"".contains(first) else {
            return false
        }
        return true
    }

    /// False when the text right after the caret already separates words
    /// ("this| sentence", "this|, and"), so no trailing space is needed.
    static func needsTrailingSpace(after textAfterCursor: String?, text: String) -> Bool {
        if text.last?.isNewline == true { return false }
        guard let next = textAfterCursor?.first else { return true }
        return !(next.isWhitespace || ".,?!;:)\"”’".contains(next))
    }

    struct Surroundings {
        let before: String
        let after: String
    }

    static func focusedElement() -> AXUIElement? {
        func focused(in container: AXUIElement) -> AXUIElement? {
            // Don't let an unresponsive app stall the paste.
            AXUIElementSetMessagingTimeout(container, 0.25)
            var ref: CFTypeRef?
            guard AXUIElementCopyAttributeValue(container, kAXFocusedUIElementAttribute as CFString, &ref) == .success,
                  let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
            return (ref as! AXUIElement)
        }
        // The system-wide query can fail (kAXErrorCannotComplete) while the
        // frontmost app still answers directly.
        if let element = focused(in: AXUIElementCreateSystemWide()) { return element }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        return focused(in: AXUIElementCreateApplication(pid))
    }

    /// Up to `maxLength` characters before the caret and one after it, or nil
    /// if the focused app doesn't expose its text.
    static func surroundingText(maxLength: Int = 200) -> Surroundings? {
        guard AXIsProcessTrusted() else { return nil }
        guard let element = focusedElement() else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.25)

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef, CFGetTypeID(rangeRef) == AXValueGetTypeID() else {
            return nil
        }
        var selection = CFRange()
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &selection), selection.location >= 0 else {
            return nil
        }
        // Pasting replaces the selection, so "after" starts past its end.
        let selectionEnd = selection.location + selection.length

        // Ranged queries avoid copying a long document. AX ranges are UTF-16 offsets.
        func string(_ location: Int, _ length: Int) -> String? {
            guard length > 0 else { return "" }
            var range = CFRange(location: location, length: length)
            guard let rangeValue = AXValueCreate(.cfRange, &range) else { return nil }
            var stringRef: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString,
                                                             rangeValue, &stringRef) == .success else { return nil }
            return stringRef as? String
        }
        let start = max(0, selection.location - maxLength)
        if let before = string(start, selection.location - start) {
            return Surroundings(before: before, after: string(selectionEnd, 1) ?? "")
        }

        // Fallback for fields that only expose their whole value.
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let value = valueRef as? String else {
            return nil
        }
        let utf16 = Array(value.utf16)
        guard selectionEnd <= utf16.count else { return nil }
        return Surroundings(
            before: String(decoding: utf16[start..<selection.location], as: UTF16.self),
            after: String(decoding: utf16[selectionEnd..<min(utf16.count, selectionEnd + 1)], as: UTF16.self))
    }
}
