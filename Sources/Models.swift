import Foundation

struct SnapshotResult: Codable {
    let timestamp: Date
    let elements: [AccessibleElement]
    let screenSize: ScreenSize
}

struct AccessibleElement: Codable {
    let id: String
    let role: String
    let subrole: String?
    let title: String?
    let description: String?
    let value: String?
    let frame: [Double]?  // [x, y, width, height]
    let actions: [String]
    let children: [AccessibleElement]?
    let enabled: Bool
    let focused: Bool
    let selected: Bool?
    let attributes: [String: String]
}

struct ScreenSize: Codable {
    let width: Double
    let height: Double
}
