import ApplicationServices
import Foundation

class GestureActions {
    private let cgActions = CGEventActions()

    func perform(
        gesture: String,
        fromX: Double?, fromY: Double?,
        toX: Double?, toY: Double?,
        duration: Int
    ) throws {
        switch gesture.lowercased() {
        case "drag":
            guard let fromX = fromX, let fromY = fromY, let toX = toX, let toY = toY else {
                throw GestureError.missingCoordinates
            }
            try performDrag(fromX: fromX, fromY: fromY, toX: toX, toY: toY)

        case "hover":
            guard let x = fromX, let y = fromY else {
                throw GestureError.missingCoordinates
            }
            try performHover(x: x, y: y, duration: duration)

        case "selecttext":
            guard let fromX = fromX, let fromY = fromY, let toX = toX, let toY = toY else {
                throw GestureError.missingCoordinates
            }
            try performTextSelection(fromX: fromX, fromY: fromY, toX: toX, toY: toY)

        case "doubleclick":
            guard let x = fromX, let y = fromY else {
                throw GestureError.missingCoordinates
            }
            try performDoubleClick(x: x, y: y)

        case "rightclick":
            guard let x = fromX, let y = fromY else {
                throw GestureError.missingCoordinates
            }
            try performRightClick(x: x, y: y)

        case "tripleclick":
            guard let x = fromX, let y = fromY else {
                throw GestureError.missingCoordinates
            }
            try performTripleClick(x: x, y: y)

        default:
            throw GestureError.unknownGesture(gesture)
        }
    }

    private func performDrag(fromX: Double, fromY: Double, toX: Double, toY: Double) throws {
        // Move to start position
        try cgActions.perform(
            event: "mousemove",
            x: fromX, y: fromY,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        usleep(50_000) // 50ms delay

        // Mouse down
        try cgActions.perform(
            event: "mousedown",
            x: fromX, y: fromY,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        usleep(50_000)

        // Interpolate movement for smooth drag
        let steps = 20
        for i in 1...steps {
            let progress = Double(i) / Double(steps)
            let currentX = fromX + (toX - fromX) * progress
            let currentY = fromY + (toY - fromY) * progress

            try cgActions.perform(
                event: "mousemove",
                x: currentX, y: currentY,
                button: "left", key: nil,
                deltaX: nil, deltaY: nil,
                shift: false, command: false, option: false, control: false
            )

            usleep(10_000) // 10ms between steps
        }

        usleep(50_000)

        // Mouse up
        try cgActions.perform(
            event: "mouseup",
            x: toX, y: toY,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )
    }

    private func performHover(x: Double, y: Double, duration: Int) throws {
        // Move to position
        try cgActions.perform(
            event: "mousemove",
            x: x, y: y,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        // Wait for duration
        usleep(UInt32(duration * 1000))
    }

    private func performTextSelection(fromX: Double, fromY: Double, toX: Double, toY: Double) throws {
        // Move to start position
        try cgActions.perform(
            event: "mousemove",
            x: fromX, y: fromY,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        usleep(50_000)

        // Mouse down
        try cgActions.perform(
            event: "mousedown",
            x: fromX, y: fromY,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        usleep(100_000)

        // Drag to end position with shift held (for text selection)
        let steps = 15
        for i in 1...steps {
            let progress = Double(i) / Double(steps)
            let currentX = fromX + (toX - fromX) * progress
            let currentY = fromY + (toY - fromY) * progress

            try cgActions.perform(
                event: "mousemove",
                x: currentX, y: currentY,
                button: "left", key: nil,
                deltaX: nil, deltaY: nil,
                shift: false, command: false, option: false, control: false
            )

            usleep(15_000)
        }

        usleep(50_000)

        // Mouse up
        try cgActions.perform(
            event: "mouseup",
            x: toX, y: toY,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )
    }

    private func performDoubleClick(x: Double, y: Double) throws {
        // First click
        try cgActions.perform(
            event: "mousedown",
            x: x, y: y,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        usleep(50_000)

        try cgActions.perform(
            event: "mouseup",
            x: x, y: y,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        usleep(100_000) // 100ms between clicks

        // Second click
        try cgActions.perform(
            event: "mousedown",
            x: x, y: y,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        usleep(50_000)

        try cgActions.perform(
            event: "mouseup",
            x: x, y: y,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )
    }

    private func performTripleClick(x: Double, y: Double) throws {
        // Perform double click first
        try performDoubleClick(x: x, y: y)

        usleep(100_000)

        // Third click
        try cgActions.perform(
            event: "mousedown",
            x: x, y: y,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        usleep(50_000)

        try cgActions.perform(
            event: "mouseup",
            x: x, y: y,
            button: "left", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )
    }

    private func performRightClick(x: Double, y: Double) throws {
        try cgActions.perform(
            event: "mousedown",
            x: x, y: y,
            button: "right", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )

        usleep(50_000)

        try cgActions.perform(
            event: "mouseup",
            x: x, y: y,
            button: "right", key: nil,
            deltaX: nil, deltaY: nil,
            shift: false, command: false, option: false, control: false
        )
    }
}

enum GestureError: Error, CustomStringConvertible {
    case unknownGesture(String)
    case missingCoordinates

    var description: String {
        switch self {
        case .unknownGesture(let gesture):
            return "Unknown gesture: \(gesture)"
        case .missingCoordinates:
            return "Missing required coordinates for gesture"
        }
    }
}
