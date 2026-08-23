import Foundation

public enum LRCParserError: Error, Equatable {
    case noTimedLines
}

public struct LRCParseResult: Sendable {
    public var lines: [LyricLine]
    public var metadata: [String: String]
    public var fileOffset: TimeInterval

    public init(lines: [LyricLine], metadata: [String: String], fileOffset: TimeInterval) {
        self.lines = lines
        self.metadata = metadata
        self.fileOffset = fileOffset
    }
}

public struct LRCParser: Sendable {
    private static let timestampRegex = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]"#
    )
    private static let hourTimestampRegex = try! NSRegularExpression(
        pattern: #"\[(\d{1,2}):(\d{2}):(\d{2})(?:[\.:](\d{1,3}))?\]"#
    )
    private static let metadataRegex = try! NSRegularExpression(
        pattern: #"^\[([A-Za-z]+):\s*(.*?)\]\s*$"#
    )
    private static let enhancedTimestampRegex = try! NSRegularExpression(
        pattern: #"<\d{1,3}:\d{2}(?:[\.:]\d{1,3})?>"#
    )

    public init() {}

    public func parse(_ source: String) throws -> LRCParseResult {
        var metadata: [String: String] = [:]
        var rawLines: [(time: TimeInterval, text: String)] = []

        for originalLine in source.components(separatedBy: .newlines) {
            let line = originalLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = Self.metadataRegex.firstMatch(in: line, range: fullRange),
               let keyRange = Range(match.range(at: 1), in: line),
               let valueRange = Range(match.range(at: 2), in: line) {
                let key = String(line[keyRange]).lowercased()
                let value = String(line[valueRange]).trimmingCharacters(in: .whitespaces)
                metadata[key] = value
                continue
            }

            let hourMatches = Self.hourTimestampRegex.matches(in: line, range: fullRange)
            let standardMatches = Self.timestampRegex.matches(in: line, range: fullRange)
                .filter { candidate in
                    !hourMatches.contains(where: { NSIntersectionRange($0.range, candidate.range).length > 0 })
                }
            let matches = hourMatches + standardMatches
            guard !matches.isEmpty else { continue }

            var lyricText = line
            for match in matches.sorted(by: { $0.range.location > $1.range.location }) {
                if let range = Range(match.range, in: lyricText) {
                    lyricText.removeSubrange(range)
                }
            }
            lyricText = Self.enhancedTimestampRegex
                .stringByReplacingMatches(
                    in: lyricText,
                    range: NSRange(lyricText.startIndex..<lyricText.endIndex, in: lyricText),
                    withTemplate: ""
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for match in matches {
                if let timestamp = parseTimestamp(match: match, in: line, isHourFormat: hourMatches.contains(where: { $0 === match })) {
                    rawLines.append((timestamp, lyricText))
                }
            }
        }

        let offsetMilliseconds = Double(metadata["offset"] ?? "0") ?? 0
        let fileOffset = offsetMilliseconds / 1_000

        var deduplicated: [Int: (TimeInterval, String)] = [:]
        for item in rawLines {
            let adjusted = max(0, item.time + fileOffset)
            let key = Int((adjusted * 1_000).rounded())
            if let existing = deduplicated[key] {
                if existing.1.isEmpty && !item.text.isEmpty {
                    deduplicated[key] = (adjusted, item.text)
                }
            } else {
                deduplicated[key] = (adjusted, item.text)
            }
        }

        let sorted = deduplicated.values.sorted { lhs, rhs in
            if lhs.0 == rhs.0 { return lhs.1 < rhs.1 }
            return lhs.0 < rhs.0
        }
        guard !sorted.isEmpty else { throw LRCParserError.noTimedLines }

        let lines = sorted.enumerated().map { offset, value in
            LyricLine(index: offset, timestamp: value.0, text: value.1)
        }
        return LRCParseResult(lines: lines, metadata: metadata, fileOffset: fileOffset)
    }

    private func parseTimestamp(
        match: NSTextCheckingResult,
        in source: String,
        isHourFormat: Bool
    ) -> TimeInterval? {
        func number(_ group: Int) -> Double? {
            guard group < match.numberOfRanges,
                  let range = Range(match.range(at: group), in: source) else { return nil }
            return Double(source[range])
        }

        if isHourFormat {
            guard let hours = number(1), let minutes = number(2), let seconds = number(3) else { return nil }
            return hours * 3_600 + minutes * 60 + seconds + fraction(match: match, group: 4, source: source)
        }
        guard let minutes = number(1), let seconds = number(2) else { return nil }
        return minutes * 60 + seconds + fraction(match: match, group: 3, source: source)
    }

    private func fraction(match: NSTextCheckingResult, group: Int, source: String) -> Double {
        guard group < match.numberOfRanges,
              match.range(at: group).location != NSNotFound,
              let range = Range(match.range(at: group), in: source) else { return 0 }
        let digits = String(source[range])
        guard let value = Double(digits) else { return 0 }
        return value / pow(10, Double(digits.count))
    }
}
