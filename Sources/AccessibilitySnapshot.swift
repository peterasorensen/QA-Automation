import ApplicationServices
import Cocoa
import Foundation

class AccessibilitySnapshot {
    private var elementCache: [String: AXUIElement] = [:]

    func capture(app: String?, systemWide: Bool) throws -> SnapshotResult {
        // Check accessibility permissions
        guard AXIsProcessTrusted() else {
            throw SnapshotError.accessibilityNotEnabled
        }

        var elements: [AccessibleElement] = []

        // Get screen size
        let screenSize = NSScreen.main?.frame.size ?? .zero

        if systemWide {
            // Capture all running applications
            let workspace = NSWorkspace.shared
            let runningApps = workspace.runningApplications.filter {
                $0.activationPolicy == .regular
            }

            for runningApp in runningApps {
                if let appElement = try? captureApplication(pid: runningApp.processIdentifier) {
                    elements.append(appElement)
                }
            }
        } else if let app = app {
            // Target specific app
            if let appElement = try captureTargetApplication(target: app) {
                elements.append(appElement)
            }
        } else {
            // Capture frontmost app
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                if let appElement = try? captureApplication(pid: frontApp.processIdentifier) {
                    elements.append(appElement)
                }
            }
        }

        return SnapshotResult(
            timestamp: Date(),
            elements: elements,
            screenSize: ScreenSize(width: Double(screenSize.width), height: Double(screenSize.height))
        )
    }

    private func captureTargetApplication(target: String) throws -> AccessibleElement? {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        // Try bundle ID first
        if let app = runningApps.first(where: { $0.bundleIdentifier == target }) {
            return try captureApplication(pid: app.processIdentifier)
        }

        // Try by name
        if let app = runningApps.first(where: { $0.localizedName == target }) {
            return try captureApplication(pid: app.processIdentifier)
        }

        throw SnapshotError.applicationNotFound(target)
    }

    private func captureApplication(pid: pid_t) throws -> AccessibleElement {
        let appElement = AXUIElementCreateApplication(pid)
        return try traverseElement(appElement, depth: 0, maxDepth: 10000)
    }

    private func traverseElement(_ element: AXUIElement, depth: Int, maxDepth: Int) throws -> AccessibleElement {
        let id = UUID().uuidString
        elementCache[id] = element

        // Get basic attributes
        let role = getAttribute(element, .role) as? String ?? "Unknown"
        let subrole = getAttribute(element, .subrole) as? String
        let title = getAttribute(element, .title) as? String
        let description = getAttribute(element, .description) as? String
        let value = getValueAsString(element)
        let enabled = (getAttribute(element, .enabled) as? Bool) ?? false
        let focused = (getAttribute(element, .focused) as? Bool) ?? false
        let selected = getAttribute(element, .selected) as? Bool

        // Get frame
        let frame = getFrame(element)

        // Get available actions
        let actions = getActions(element)

        // Get additional attributes
        var attributes: [String: String] = [:]
        if let label = getAttribute(element, .roleDescription) as? String {
            attributes["roleDescription"] = label
        }
        if let help = getAttribute(element, .help) as? String {
            attributes["help"] = help
        }
        if let placeholder = getAttribute(element, .placeholderValue) as? String {
            attributes["placeholder"] = placeholder
        }

        // Get children - traverse everything, no depth limit
        var children: [AccessibleElement]? = nil
        if depth < maxDepth {
            children = getChildren(element, depth: depth, maxDepth: maxDepth)
        }

        return AccessibleElement(
            id: id,
            role: role,
            subrole: subrole,
            title: title,
            description: description,
            value: value,
            frame: frame,
            actions: actions,
            children: children,
            enabled: enabled,
            focused: focused,
            selected: selected,
            attributes: attributes
        )
    }

    private func getChildren(_ element: AXUIElement, depth: Int, maxDepth: Int) -> [AccessibleElement]? {
        guard let children = getAttribute(element, .children) as? [AXUIElement] else {
            return nil
        }

        var result: [AccessibleElement] = []
        for child in children {
            if let childElement = try? traverseElement(child, depth: depth + 1, maxDepth: maxDepth) {
                result.append(childElement)
            }
        }

        return result.isEmpty ? nil : result
    }

    private func getAttribute(_ element: AXUIElement, _ attribute: NSAccessibility.Attribute) -> AnyObject? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute.rawValue as CFString, &value)
        return error == .success ? value : nil
    }

    private func getValueAsString(_ element: AXUIElement) -> String? {
        guard let value = getAttribute(element, .value) else { return nil }

        if let stringValue = value as? String {
            return stringValue
        } else if let numberValue = value as? NSNumber {
            return numberValue.stringValue
        } else {
            return String(describing: value)
        }
    }

    private func getFrame(_ element: AXUIElement) -> [Double]? {
        guard let positionValue = getAttribute(element, .position),
              let sizeValue = getAttribute(element, .size) else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        return [Double(position.x), Double(position.y), Double(size.width), Double(size.height)]
    }

    private func getActions(_ element: AXUIElement) -> [String] {
        var actionsRef: CFArray?
        let error = AXUIElementCopyActionNames(element, &actionsRef)

        guard error == .success, let actions = actionsRef as? [String] else {
            return []
        }
        return actions
    }

    func getElementFromCache(_ id: String) -> AXUIElement? {
        return elementCache[id]
    }
}

enum SnapshotError: Error, CustomStringConvertible {
    case accessibilityNotEnabled
    case applicationNotFound(String)
    case elementNotFound

    var description: String {
        switch self {
        case .accessibilityNotEnabled:
            return "Accessibility permissions not granted. Enable in System Preferences > Security & Privacy > Privacy > Accessibility"
        case .applicationNotFound(let name):
            return "Application not found: \(name)"
        case .elementNotFound:
            return "Element not found in cache"
        }
    }
}
