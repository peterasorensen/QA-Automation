import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

class VisualSnapshot {
    static let shared = VisualSnapshot()
    private var elementCache: [String: AXUIElement] = [:]

    enum OutputFormat {
        case base64
        case file(String)
        case both(String)
    }

    private init() {}

    func capture(
        app: String?,
        systemWide: Bool,
        displayID: CGDirectDisplayID? = nil,
        format: OutputFormat = .base64,
        minElementSize: CGFloat = 20.0,  // Minimum width/height to avoid tiny sub-elements
        maxElementSize: CGFloat = 800.0,  // Maximum size to avoid large containers
        includeDebugTree: Bool = false
    ) throws -> VisualSnapshotResult {
        // Check accessibility permissions
        guard AXIsProcessTrusted() else {
            throw VisualSnapshotError.accessibilityNotEnabled
        }

        // Step 1: Capture screenshot
        let displayID = displayID ?? CGMainDisplayID()
        guard let cgImage = CGDisplayCreateImage(displayID) else {
            throw VisualSnapshotError.captureFailed
        }

        let screenSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Step 2: Get visible windows (already sorted by z-order, front to back)
        let visibleWindows = try getVisibleWindows()

        // Step 3: Get accessibility elements
        let accessibilityElements = try captureAccessibilityElements(
            app: app,
            systemWide: systemWide
        )

        // Step 4: Use DFS to collect interactable elements, preferring deeper (more specific) elements
        let interactableElements = collectInteractableElementsDFS(
            accessibilityElements,
            minSize: minElementSize,
            maxSize: maxElementSize,
            windows: visibleWindows
        )

        // Step 5: Draw bounding boxes on screenshot
        let annotatedImage = drawBoundingBoxes(
            on: cgImage,
            elements: interactableElements
        )

        // Step 7: Convert to output format
        let imageOutput = try encodeImage(annotatedImage, format: format)

        return VisualSnapshotResult(
            timestamp: Date(),
            screenSize: ScreenSize(width: Double(screenSize.width), height: Double(screenSize.height)),
            visibleWindows: visibleWindows.map { WindowInfo(
                windowID: Int($0.windowID),
                ownerName: $0.ownerName,
                bounds: DisplayBounds(
                    x: $0.bounds.origin.x,
                    y: $0.bounds.origin.y,
                    width: $0.bounds.size.width,
                    height: $0.bounds.size.height
                ),
                layer: $0.layer
            )},
            interactableElements: interactableElements.map { InteractableElementInfo(
                id: $0.id,
                role: $0.role,
                title: $0.title,
                description: $0.description,
                value: $0.value,
                frame: DisplayBounds(
                    x: $0.bounds.origin.x,
                    y: $0.bounds.origin.y,
                    width: $0.bounds.size.width,
                    height: $0.bounds.size.height
                ),
                actions: $0.actions,
                enabled: $0.enabled
            )},
            imageData: imageOutput,
            debugTree: includeDebugTree ? accessibilityElements : nil
        )
    }

    // MARK: - Window Management

    private struct WindowData {
        let windowID: CGWindowID
        let ownerName: String
        let bounds: CGRect
        let layer: Int
    }

    private func getVisibleWindows() throws -> [WindowData] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw VisualSnapshotError.windowEnumerationFailed
        }

        var windows: [WindowData] = []

        for (index, windowInfo) in windowList.enumerated() {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String else {
                continue
            }

            // Parse bounds
            let x = boundsDict["X"] ?? 0
            let y = boundsDict["Y"] ?? 0
            let width = boundsDict["Width"] ?? 0
            let height = boundsDict["Height"] ?? 0
            let bounds = CGRect(x: x, y: y, width: width, height: height)

            // Skip windows with zero area
            if bounds.width <= 0 || bounds.height <= 0 {
                continue
            }

            windows.append(WindowData(
                windowID: windowID,
                ownerName: ownerName,
                bounds: bounds,
                layer: index  // Index represents z-order (front = 0, back = higher values)
            ))
        }

        return windows
    }

    // MARK: - Accessibility Elements

    private struct InteractableElement {
        let id: String
        let role: String
        let title: String?
        let description: String?
        let value: String?
        let bounds: CGRect
        let actions: [String]
        let enabled: Bool
        let axElement: AXUIElement
        let layer: Int
    }

    private func captureAccessibilityElements(app: String?, systemWide: Bool) throws -> [AccessibleElement] {
        var elements: [AccessibleElement] = []

        if systemWide {
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
            if let appElement = try captureTargetApplication(target: app) {
                elements.append(appElement)
            }
        } else {
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                if let appElement = try? captureApplication(pid: frontApp.processIdentifier) {
                    elements.append(appElement)
                }
            }
        }

        return elements
    }

    private func captureTargetApplication(target: String) throws -> AccessibleElement? {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        if let app = runningApps.first(where: { $0.bundleIdentifier == target }) {
            return try captureApplication(pid: app.processIdentifier)
        }

        if let app = runningApps.first(where: { $0.localizedName == target }) {
            return try captureApplication(pid: app.processIdentifier)
        }

        throw VisualSnapshotError.applicationNotFound(target)
    }

    private func captureApplication(pid: pid_t) throws -> AccessibleElement {
        let appElement = AXUIElementCreateApplication(pid)
        return try traverseElement(appElement, depth: 0, maxDepth: 10000)
    }

    private func traverseElement(_ element: AXUIElement, depth: Int, maxDepth: Int) throws -> AccessibleElement {
        let id = UUID().uuidString
        elementCache[id] = element

        let role = getAttribute(element, .role) as? String ?? "Unknown"
        let subrole = getAttribute(element, .subrole) as? String
        let title = getAttribute(element, .title) as? String
        let description = getAttribute(element, .description) as? String
        let value = getValueAsString(element)
        let enabled = (getAttribute(element, .enabled) as? Bool) ?? false
        let focused = (getAttribute(element, .focused) as? Bool) ?? false
        let selected = getAttribute(element, .selected) as? Bool
        let frame = getFrame(element)
        let actions = getActions(element)

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

    // MARK: - Element Processing

    private func collectInteractableElementsDFS(
        _ elements: [AccessibleElement],
        minSize: CGFloat,
        maxSize: CGFloat,
        windows: [WindowData]
    ) -> [InteractableElement] {
        var drawnBoxes: [CGRect] = []
        var visibleElements: [InteractableElement] = []

        // Define clickable roles we want to annotate
        let clickableRoles: Set<String> = [
            "AXButton",
            "AXRadioButton",
            "AXCheckBox",
            "AXTextField",
            "AXTextArea",
            "AXComboBox",
            "AXPopUpButton",
            "AXMenuItem",
            "AXMenuButton",
            "AXLink",
            "AXTab",
            "AXSlider",
            "AXIncrementor",
            "AXSegmentedControl",
            "AXSearchField",
            "AXStaticText",  // Sometimes clickable (links in text)
            "AXImage",       // Sometimes clickable (image buttons)
            "AXCell"         // Table/list cells
        ]

        // DFS traversal: process children before parents
        // This prioritizes more specific (smaller) elements over generic (larger) ones
        func traverseDFS(_ element: AccessibleElement) {
            // First, recurse into children (depth-first)
            if let children = element.children {
                for child in children {
                    traverseDFS(child)
                }
            }

            // Then process this element
            guard let frame = element.frame,
                  frame.count == 4,
                  !element.actions.isEmpty else {
                return
            }

            let bounds = CGRect(
                x: frame[0],
                y: frame[1],
                width: frame[2],
                height: frame[3]
            )

            // Skip elements below minimum size threshold
            guard bounds.width >= minSize && bounds.height >= minSize else {
                return
            }

            // Skip elements above maximum size threshold (likely containers)
            guard bounds.width <= maxSize && bounds.height <= maxSize else {
                return
            }

            // Skip if element has zero area
            guard bounds.width > 0 && bounds.height > 0 else {
                return
            }

            // Only include elements with clickable roles
            guard clickableRoles.contains(element.role) else {
                return
            }

            // Get AXUIElement from cache
            guard let axElement = elementCache[element.id] else {
                return
            }

            // Find containing window for z-order
            let containingWindow = findContainingWindow(for: bounds, in: windows)
            let layer = containingWindow?.layer ?? Int.max

            // Add to candidates (we'll filter by overlap after sorting by z-order)
            let interactableElement = InteractableElement(
                id: element.id,
                role: element.role,
                title: element.title,
                description: element.description,
                value: element.value,
                bounds: bounds,
                actions: element.actions,
                enabled: element.enabled,
                axElement: axElement,
                layer: layer
            )

            visibleElements.append(interactableElement)
        }

        // Start DFS from each root element
        for element in elements {
            traverseDFS(element)
        }

        // Sort by z-order (lower layer = front, should be drawn first)
        visibleElements.sort { $0.layer < $1.layer }

        // Now filter by overlap - process front-to-back
        var filteredElements: [InteractableElement] = []
        for element in visibleElements {
            // Check if this element overlaps significantly with already drawn boxes
            let hasSignificantOverlap = drawnBoxes.contains { existingBox in
                let intersection = element.bounds.intersection(existingBox)
                if intersection.isNull {
                    return false
                }
                // Consider it overlapping if intersection is more than 70% of this element's area
                let thisArea = element.bounds.width * element.bounds.height
                let intersectionArea = intersection.width * intersection.height
                return intersectionArea / thisArea > 0.7
            }

            // If no significant overlap, add this element
            if !hasSignificantOverlap {
                filteredElements.append(element)
                drawnBoxes.append(element.bounds)
            }
        }

        return filteredElements
    }

    private func findContainingWindow(for bounds: CGRect, in windows: [WindowData]) -> WindowData? {
        // Find the frontmost window that contains this element
        for window in windows {
            if window.bounds.contains(bounds) ||
               window.bounds.intersects(bounds) {
                return window
            }
        }
        return nil
    }

    // MARK: - Image Processing

    private func drawBoundingBoxes(on cgImage: CGImage, elements: [InteractableElement]) -> NSImage {
        // Get screen dimensions in points
        let mainScreen = NSScreen.main!
        let screenFrame = mainScreen.frame
        let screenPointsWidth = screenFrame.width
        let screenPointsHeight = screenFrame.height

        // Calculate scale factor (pixels / points)
        let scaleX = CGFloat(cgImage.width) / screenPointsWidth
        let scaleY = CGFloat(cgImage.height) / screenPointsHeight

        // Image size in pixels
        let imagePixelSize = NSSize(width: cgImage.width, height: cgImage.height)

        // Create NSImage with correct size representation
        // We set the size to pixel dimensions so drawing coordinates match
        let image = NSImage(cgImage: cgImage, size: imagePixelSize)

        // Create a new image with bounding boxes
        let newImage = NSImage(size: imagePixelSize)
        newImage.lockFocus()

        // Draw original image
        image.draw(at: .zero, from: NSRect(origin: .zero, size: imagePixelSize), operation: .copy, fraction: 1.0)

        // Define color palette (basic colors)
        let colors: [NSColor] = [
            .systemRed,
            .systemBlue,
            .systemGreen,
            .systemOrange,
            .systemPurple,
            .systemPink,
            .systemYellow,
            .systemTeal
        ]

        // Draw bounding boxes with labels
        for (index, element) in elements.enumerated() {
            // Accessibility coordinates are in points with top-left origin
            // We need to convert to pixels with bottom-left origin (AppKit coordinate system)

            // Scale from points to pixels
            let scaledX = element.bounds.origin.x * scaleX
            let scaledWidth = element.bounds.width * scaleX
            let scaledHeight = element.bounds.height * scaleY

            // Flip Y coordinate (top-left to bottom-left)
            // In screen coordinates (top-left): y = element.bounds.origin.y
            // In AppKit (bottom-left): y = screenHeight - (element.y + element.height)
            let scaledY = (screenPointsHeight - (element.bounds.origin.y + element.bounds.height)) * scaleY

            let rect = NSRect(
                x: scaledX,
                y: scaledY,
                width: scaledWidth,
                height: scaledHeight
            )

            // Pick color from palette (cycle through)
            let color = colors[index % colors.count]

            // Draw semi-transparent fill
            color.withAlphaComponent(0.2).setFill()
            rect.fill()

            // Draw border (thinner)
            color.setStroke()
            let border = NSBezierPath(rect: rect)
            border.lineWidth = 1.5 * scaleX
            border.stroke()

            // Draw label with index number (smaller)
            let label = "\(index + 1)"
            let fontSize = 12.0 * scaleX
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: NSColor.white,
                .backgroundColor: color.withAlphaComponent(0.9)
            ]

            let labelSize = label.size(withAttributes: attributes)
            let labelRect = NSRect(
                x: rect.origin.x,
                y: rect.origin.y,
                width: labelSize.width + 4,
                height: labelSize.height + 2
            )

            label.draw(in: labelRect, withAttributes: attributes)
        }

        newImage.unlockFocus()
        return newImage
    }

    private func encodeImage(_ image: NSImage, format: OutputFormat) throws -> String {
        guard let pngData = image.pngData() else {
            throw VisualSnapshotError.encodingFailed
        }

        switch format {
        case .base64:
            return pngData.base64EncodedString()

        case .file(let path):
            try pngData.write(to: URL(fileURLWithPath: path))
            return path

        case .both(let path):
            try pngData.write(to: URL(fileURLWithPath: path))
            return pngData.base64EncodedString()
        }
    }

    func getElementFromCache(_ id: String) -> AXUIElement? {
        return elementCache[id]
    }
}

// MARK: - Models

struct VisualSnapshotResult: Codable {
    let timestamp: Date
    let screenSize: ScreenSize
    let visibleWindows: [WindowInfo]
    let interactableElements: [InteractableElementInfo]
    let imageData: String
    let debugTree: [AccessibleElement]?
}

struct WindowInfo: Codable {
    let windowID: Int
    let ownerName: String
    let bounds: DisplayBounds
    let layer: Int
}

struct InteractableElementInfo: Codable {
    let id: String
    let role: String
    let title: String?
    let description: String?
    let value: String?
    let frame: DisplayBounds
    let actions: [String]
    let enabled: Bool
}

enum VisualSnapshotError: Error, CustomStringConvertible {
    case accessibilityNotEnabled
    case applicationNotFound(String)
    case captureFailed
    case encodingFailed
    case windowEnumerationFailed

    var description: String {
        switch self {
        case .accessibilityNotEnabled:
            return "Accessibility permissions not granted. Enable in System Preferences > Security & Privacy > Privacy > Accessibility"
        case .applicationNotFound(let name):
            return "Application not found: \(name)"
        case .captureFailed:
            return "Failed to capture screen"
        case .encodingFailed:
            return "Failed to encode image to PNG"
        case .windowEnumerationFailed:
            return "Failed to enumerate windows"
        }
    }
}
