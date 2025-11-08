import AppKit
import CoreGraphics
import Foundation

class ScreenshotCapture {
    enum OutputFormat {
        case base64
        case file(String)
        case both(String)
    }

    func capture(displayID: CGDirectDisplayID? = nil, format: OutputFormat = .base64) throws -> String {
        // Capture screenshot
        let image = try captureScreen(displayID: displayID)

        // Convert to PNG data
        guard let pngData = image.pngData() else {
            throw ScreenshotError.encodingFailed
        }

        switch format {
        case .base64:
            return pngData.base64EncodedString()

        case .file(let path):
            try pngData.write(to: URL(fileURLWithPath: path))
            return path

        case .both(let path):
            try pngData.write(to: URL(fileURLWithPath: path))
            let base64 = pngData.base64EncodedString()
            return """
            {
              "file_path": "\(path)",
              "base64": "\(base64)"
            }
            """
        }
    }

    private func captureScreen(displayID: CGDirectDisplayID?) throws -> NSImage {
        let displayID = displayID ?? CGMainDisplayID()

        // Capture the display
        guard let cgImage = CGDisplayCreateImage(displayID) else {
            throw ScreenshotError.captureFailed
        }

        // Convert to NSImage
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)

        return image
    }

    func captureAllDisplays() throws -> [DisplayScreenshot] {
        var screenshots: [DisplayScreenshot] = []

        // Get all online displays
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)

        guard CGGetOnlineDisplayList(16, &displays, &displayCount) == .success else {
            throw ScreenshotError.displayEnumerationFailed
        }

        for i in 0..<Int(displayCount) {
            let displayID = displays[i]
            let bounds = CGDisplayBounds(displayID)

            if let cgImage = CGDisplayCreateImage(displayID) {
                let size = NSSize(width: cgImage.width, height: cgImage.height)
                let image = NSImage(cgImage: cgImage, size: size)

                if let pngData = image.pngData() {
                    screenshots.append(DisplayScreenshot(
                        displayID: displayID,
                        bounds: DisplayBounds(
                            x: Double(bounds.origin.x),
                            y: Double(bounds.origin.y),
                            width: Double(bounds.size.width),
                            height: Double(bounds.size.height)
                        ),
                        base64: pngData.base64EncodedString(),
                        isMain: displayID == CGMainDisplayID()
                    ))
                }
            }
        }

        return screenshots
    }
}

struct DisplayScreenshot: Codable {
    let displayID: UInt32
    let bounds: DisplayBounds
    let base64: String
    let isMain: Bool
}

struct DisplayBounds: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

enum ScreenshotError: Error, CustomStringConvertible {
    case captureFailed
    case encodingFailed
    case displayEnumerationFailed

    var description: String {
        switch self {
        case .captureFailed:
            return "Failed to capture screen"
        case .encodingFailed:
            return "Failed to encode image to PNG"
        case .displayEnumerationFailed:
            return "Failed to enumerate displays"
        }
    }
}

// Extension to convert NSImage to PNG data
extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
