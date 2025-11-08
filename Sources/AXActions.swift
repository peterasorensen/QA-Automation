import ApplicationServices
import Cocoa
import Foundation

class AXActions {
    private let snapshot = AccessibilitySnapshot()

    func perform(
        action: String,
        elementId: String,
        value: String?,
        x: Double?, y: Double?,
        width: Double?, height: Double?
    ) throws {
        guard let element = snapshot.getElementFromCache(elementId) else {
            throw AXActionError.elementNotFound(elementId)
        }

        switch action.lowercased() {
        case "press", "axpress":
            try performPress(element)
        case "increment", "axincrement":
            try performAction(element, action: kAXIncrementAction)
        case "decrement", "axdecrement":
            try performAction(element, action: kAXDecrementAction)
        case "showmenu", "axshowmenu":
            try performAction(element, action: kAXShowMenuAction)
        case "confirm", "axconfirm":
            try performAction(element, action: kAXConfirmAction)
        case "cancel", "axcancel":
            try performAction(element, action: kAXCancelAction)
        case "pick", "axpick":
            try performAction(element, action: kAXPickAction)
        case "raise", "axraise":
            try performAction(element, action: kAXRaiseAction)
        case "scrolltovisible", "axscrolltovisible":
            try performScrollToVisible(element)
        case "scrolldown", "axscrolldown":
            try performScrollDown(element)
        case "setvalue", "axsetvalue":
            guard let value = value else {
                throw AXActionError.missingParameter("value")
            }
            try setValue(element, value: value)
        case "move", "axmove":
            guard let x = x, let y = y else {
                throw AXActionError.missingParameter("x, y")
            }
            try moveElement(element, x: x, y: y)
        case "size", "axsize":
            guard let width = width, let height = height else {
                throw AXActionError.missingParameter("width, height")
            }
            try resizeElement(element, width: width, height: height)
        default:
            throw AXActionError.unknownAction(action)
        }
    }

    private func performPress(_ element: AXUIElement) throws {
        let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if error != .success {
            throw AXActionError.actionFailed("press", error)
        }
    }

    private func performAction(_ element: AXUIElement, action: String) throws {
        let error = AXUIElementPerformAction(element, action as CFString)
        if error != .success {
            throw AXActionError.actionFailed(action, error)
        }
    }

    private func performScrollToVisible(_ element: AXUIElement) throws {
        // First try the standard action
        var error = AXUIElementPerformAction(element, kAXShowMenuAction as CFString)

        // If not available, try setting attribute
        if error != .success {
            error = AXUIElementPerformAction(element, "AXScrollToVisible" as CFString)
        }

        if error != .success {
            throw AXActionError.actionFailed("scrolltovisible", error)
        }
    }

    private func performScrollDown(_ element: AXUIElement) throws {
        // Get current value
        var currentValue: AnyObject?
        var error = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)

        if error == .success, let numValue = currentValue as? NSNumber {
            let newValue = numValue.intValue + 1
            error = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFTypeRef)
        } else {
            // Try decrement action for scrollbars
            error = AXUIElementPerformAction(element, kAXDecrementAction as CFString)
        }

        if error != .success {
            throw AXActionError.actionFailed("scrolldown", error)
        }
    }

    private func setValue(_ element: AXUIElement, value: String) throws {
        // Try to set as string first
        var error = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFTypeRef)

        // If that fails, try as number
        if error != .success, let numValue = Int(value) {
            error = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, numValue as CFTypeRef)
        }

        // If still fails, try as double
        if error != .success, let doubleValue = Double(value) {
            error = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, doubleValue as CFTypeRef)
        }

        if error != .success {
            throw AXActionError.actionFailed("setvalue", error)
        }
    }

    private func moveElement(_ element: AXUIElement, x: Double, y: Double) throws {
        var position = CGPoint(x: x, y: y)
        let positionValue = AXValueCreate(.cgPoint, &position)!

        let error = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        guard error == .success else {
            throw AXActionError.actionFailed("move", error)
        }
    }

    private func resizeElement(_ element: AXUIElement, width: Double, height: Double) throws {
        var size = CGSize(width: width, height: height)
        let sizeValue = AXValueCreate(.cgSize, &size)!

        let error = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        guard error == .success else {
            throw AXActionError.actionFailed("size", error)
        }
    }
}

enum AXActionError: Error, CustomStringConvertible {
    case elementNotFound(String)
    case unknownAction(String)
    case actionFailed(String, AXError)
    case missingParameter(String)

    var description: String {
        switch self {
        case .elementNotFound(let id):
            return "Element not found in cache: \(id). Run snapshot first."
        case .unknownAction(let action):
            return "Unknown action: \(action)"
        case .actionFailed(let action, let error):
            return "Action '\(action)' failed with error: \(error.rawValue)"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        }
    }
}
