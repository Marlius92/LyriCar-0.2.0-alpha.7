import Foundation

public struct LyricLine: Codable, Hashable, Identifiable, Sendable {
    public var index: Int
    public var timestamp: TimeInterval
    public var text: String

    public init(index: Int, timestamp: TimeInterval, text: String) {
        self.index = index
        self.timestamp = max(0, timestamp)
        self.text = text
    }

    public var id: Int { index }
}
