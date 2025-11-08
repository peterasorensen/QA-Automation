import ArgumentParser
import Foundation

@main
struct MacOSAgent: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "macos-agent",
        abstract: "MacOS Accessibility API-based agent CLI",
        subcommands: [
            Snapshot.self,
            Screenshot.self,
            AXAction.self,
            CGAction.self,
            Gesture.self
        ]
    )
}

struct Snapshot: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture accessibility tree snapshot as JSON"
    )

    @Option(name: .long, help: "Target application bundle ID or name")
    var app: String?

    @Flag(name: .long, help: "Include all system-wide elements")
    var systemWide: Bool = false

    func run() throws {
        let snapshot = AccessibilitySnapshot()
        let result = try snapshot.capture(app: app, systemWide: systemWide)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(result)

        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
}

struct AXAction: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ax",
        abstract: "Perform Accessibility API actions"
    )

    @Argument(help: "Action type (press, increment, decrement, showmenu, confirm, cancel, pick, raise, scrolltovisible, scrolldown, setvalue, move, size)")
    var action: String

    @Option(name: .long, help: "Element ID from snapshot")
    var elementId: String

    @Option(name: .long, help: "Value for setvalue action")
    var value: String?

    @Option(name: .long, help: "X coordinate for move/size")
    var x: Double?

    @Option(name: .long, help: "Y coordinate for move/size")
    var y: Double?

    @Option(name: .long, help: "Width for size")
    var width: Double?

    @Option(name: .long, help: "Height for size")
    var height: Double?

    func run() throws {
        let axActions = AXActions()
        try axActions.perform(
            action: action,
            elementId: elementId,
            value: value,
            x: x, y: y,
            width: width, height: height
        )
    }
}

struct CGAction: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cg",
        abstract: "Perform CoreGraphics events"
    )

    @Argument(help: "Event type (mousedown, mouseup, mousemove, keydown, keyup, scroll)")
    var event: String

    @Option(name: .long, help: "X coordinate")
    var x: Double?

    @Option(name: .long, help: "Y coordinate")
    var y: Double?

    @Option(name: .long, help: "Mouse button (left, right, middle)")
    var button: String = "left"

    @Option(name: .long, help: "Key code or character")
    var key: String?

    @Option(name: .long, help: "Scroll delta X")
    var deltaX: Int32?

    @Option(name: .long, help: "Scroll delta Y")
    var deltaY: Int32?

    @Flag(name: .long, help: "Hold shift key")
    var shift: Bool = false

    @Flag(name: .long, help: "Hold command key")
    var command: Bool = false

    @Flag(name: .long, help: "Hold option key")
    var option: Bool = false

    @Flag(name: .long, help: "Hold control key")
    var control: Bool = false

    func run() throws {
        let cgActions = CGEventActions()
        try cgActions.perform(
            event: event,
            x: x, y: y,
            button: button,
            key: key,
            deltaX: deltaX, deltaY: deltaY,
            shift: shift, command: command, option: option, control: control
        )
    }
}

struct Gesture: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Perform combined gestures"
    )

    @Argument(help: "Gesture type (drag, hover, selecttext, doubleclick, rightclick)")
    var gesture: String

    @Option(name: .long, help: "Start X coordinate")
    var fromX: Double?

    @Option(name: .long, help: "Start Y coordinate")
    var fromY: Double?

    @Option(name: .long, help: "End X coordinate")
    var toX: Double?

    @Option(name: .long, help: "End Y coordinate")
    var toY: Double?

    @Option(name: .long, help: "Hover duration in milliseconds")
    var duration: Int = 500

    func run() throws {
        let gestures = GestureActions()
        try gestures.perform(
            gesture: gesture,
            fromX: fromX, fromY: fromY,
            toX: toX, toY: toY,
            duration: duration
        )
    }
}

struct Screenshot: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture screen as image (base64 or file)"
    )

    @Option(name: .long, help: "Output file path")
    var output: String?

    @Flag(name: .long, help: "Output as base64 (default)")
    var base64: Bool = false

    @Flag(name: .long, help: "Output both file and base64 as JSON")
    var both: Bool = false

    @Flag(name: .long, help: "Capture all displays")
    var allDisplays: Bool = false

    @Option(name: .long, help: "Display ID to capture (default: main display)")
    var displayId: UInt32?

    func run() throws {
        let screenshotCapture = ScreenshotCapture()

        if allDisplays {
            // Capture all displays
            let screenshots = try screenshotCapture.captureAllDisplays()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(screenshots)

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            // Determine output format
            let format: ScreenshotCapture.OutputFormat
            if both {
                let path = output ?? "/tmp/screenshot-\(Int(Date().timeIntervalSince1970)).png"
                format = .both(path)
            } else if let outputPath = output {
                format = .file(outputPath)
            } else {
                format = .base64
            }

            // Capture and output
            let result = try screenshotCapture.capture(displayID: displayId, format: format)
            print(result)
        }
    }
}
