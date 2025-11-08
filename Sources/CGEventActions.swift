import ApplicationServices
import Carbon
import Foundation

class CGEventActions {
    func perform(
        event: String,
        x: Double?, y: Double?,
        button: String,
        key: String?,
        deltaX: Int32?, deltaY: Int32?,
        shift: Bool, command: Bool, option: Bool, control: Bool
    ) throws {
        let modifiers = buildModifierFlags(shift: shift, command: command, option: option, control: control)

        switch event.lowercased() {
        case "mousedown":
            guard let x = x, let y = y else {
                throw CGEventError.missingParameter("x, y")
            }
            try performMouseDown(x: x, y: y, button: button, modifiers: modifiers)

        case "mouseup":
            guard let x = x, let y = y else {
                throw CGEventError.missingParameter("x, y")
            }
            try performMouseUp(x: x, y: y, button: button, modifiers: modifiers)

        case "mousemove", "mousemoved":
            guard let x = x, let y = y else {
                throw CGEventError.missingParameter("x, y")
            }
            try performMouseMove(x: x, y: y, modifiers: modifiers)

        case "keydown":
            guard let key = key else {
                throw CGEventError.missingParameter("key")
            }
            try performKeyDown(key: key, modifiers: modifiers)

        case "keyup":
            guard let key = key else {
                throw CGEventError.missingParameter("key")
            }
            try performKeyUp(key: key, modifiers: modifiers)

        case "scroll", "scrollwheel":
            let dx = deltaX ?? 0
            let dy = deltaY ?? 0
            try performScroll(deltaX: dx, deltaY: dy)

        default:
            throw CGEventError.unknownEvent(event)
        }
    }

    private func performMouseDown(x: Double, y: Double, button: String, modifiers: CGEventFlags) throws {
        let point = CGPoint(x: x, y: y)
        let mouseButton = try parseMouseButton(button)

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseButton.downType,
            mouseCursorPosition: point,
            mouseButton: mouseButton.button
        ) else {
            throw CGEventError.eventCreationFailed("mousedown")
        }

        event.flags = modifiers
        event.post(tap: .cghidEventTap)
    }

    private func performMouseUp(x: Double, y: Double, button: String, modifiers: CGEventFlags) throws {
        let point = CGPoint(x: x, y: y)
        let mouseButton = try parseMouseButton(button)

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseButton.upType,
            mouseCursorPosition: point,
            mouseButton: mouseButton.button
        ) else {
            throw CGEventError.eventCreationFailed("mouseup")
        }

        event.flags = modifiers
        event.post(tap: .cghidEventTap)
    }

    private func performMouseMove(x: Double, y: Double, modifiers: CGEventFlags) throws {
        let point = CGPoint(x: x, y: y)

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            throw CGEventError.eventCreationFailed("mousemove")
        }

        event.flags = modifiers
        event.post(tap: .cghidEventTap)
    }

    private func performKeyDown(key: String, modifiers: CGEventFlags) throws {
        let keyCode = try parseKeyCode(key)

        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        ) else {
            throw CGEventError.eventCreationFailed("keydown")
        }

        event.flags = modifiers
        event.post(tap: .cghidEventTap)
    }

    private func performKeyUp(key: String, modifiers: CGEventFlags) throws {
        let keyCode = try parseKeyCode(key)

        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            throw CGEventError.eventCreationFailed("keyup")
        }

        event.flags = modifiers
        event.post(tap: .cghidEventTap)
    }

    private func performScroll(deltaX: Int32, deltaY: Int32) throws {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: deltaY,
            wheel2: deltaX,
            wheel3: 0
        ) else {
            throw CGEventError.eventCreationFailed("scroll")
        }

        event.post(tap: .cghidEventTap)
    }

    private func parseMouseButton(_ button: String) throws -> (button: CGMouseButton, downType: CGEventType, upType: CGEventType) {
        switch button.lowercased() {
        case "left":
            return (.left, .leftMouseDown, .leftMouseUp)
        case "right":
            return (.right, .rightMouseDown, .rightMouseUp)
        case "middle", "center":
            return (.center, .otherMouseDown, .otherMouseUp)
        default:
            throw CGEventError.invalidMouseButton(button)
        }
    }

    private func parseKeyCode(_ key: String) throws -> CGKeyCode {
        // Try to parse as number first
        if let code = UInt16(key) {
            return code
        }

        // Map common key names to codes
        let keyMap: [String: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
            "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
            "=": 24, "9": 25, "7": 26, "minus": 27, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32,
            "[": 33, "i": 34, "p": 35, "return": 36, "enter": 36, "l": 37, "j": 38, "'": 39, "quote": 39,
            "k": 40, ";": 41, "semicolon": 41, "\\": 42, "backslash": 42, ",": 43, "comma": 43, "/": 44,
            "slash": 44, "n": 45, "m": 46, ".": 47, "period": 47, "tab": 48, "space": 49, "`": 50,
            "grave": 50, "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
            "command": 55, "cmd": 55, "shift": 56, "capslock": 57, "option": 58, "alt": 58, "control": 59,
            "ctrl": 59, "rightshift": 60, "rightoption": 61, "rightcontrol": 62,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101,
            "f10": 109, "f11": 103, "f12": 111,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "home": 115, "end": 119, "pageup": 116, "pagedown": 121
        ]

        if let code = keyMap[key.lowercased()] {
            return code
        }

        // Try single character
        if key.count == 1, let char = key.first, let code = keyMap[String(char).lowercased()] {
            return code
        }

        throw CGEventError.invalidKeyCode(key)
    }

    private func buildModifierFlags(shift: Bool, command: Bool, option: Bool, control: Bool) -> CGEventFlags {
        var flags: CGEventFlags = []

        if shift {
            flags.insert(.maskShift)
        }
        if command {
            flags.insert(.maskCommand)
        }
        if option {
            flags.insert(.maskAlternate)
        }
        if control {
            flags.insert(.maskControl)
        }

        return flags
    }
}

enum CGEventError: Error, CustomStringConvertible {
    case unknownEvent(String)
    case eventCreationFailed(String)
    case missingParameter(String)
    case invalidMouseButton(String)
    case invalidKeyCode(String)

    var description: String {
        switch self {
        case .unknownEvent(let event):
            return "Unknown event type: \(event)"
        case .eventCreationFailed(let event):
            return "Failed to create event: \(event)"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidMouseButton(let button):
            return "Invalid mouse button: \(button). Use 'left', 'right', or 'middle'"
        case .invalidKeyCode(let key):
            return "Invalid key code: \(key)"
        }
    }
}
