import Foundation

public struct LyricFrame: Hashable, Sendable {
    public var currentIndex: Int?
    public var previous2: LyricLine?
    public var previous1: LyricLine?
    public var current: LyricLine?
    public var next1: LyricLine?
    public var next2: LyricLine?
    public var lineProgress: Double
    public var transitionProgress: Double
    /// True only when the current line has a real following timestamp that can
    /// safely drive the letter-by-letter karaoke highlight.
    public var karaokeEligible: Bool

    public init(
        currentIndex: Int?,
        previous2: LyricLine?,
        previous1: LyricLine?,
        current: LyricLine?,
        next1: LyricLine?,
        next2: LyricLine?,
        lineProgress: Double,
        transitionProgress: Double,
        karaokeEligible: Bool = false
    ) {
        self.currentIndex = currentIndex
        self.previous2 = previous2
        self.previous1 = previous1
        self.current = current
        self.next1 = next1
        self.next2 = next2
        self.lineProgress = min(max(0, lineProgress), 1)
        self.transitionProgress = min(max(0, transitionProgress), 1)
        self.karaokeEligible = karaokeEligible
    }

    public static let empty = LyricFrame(
        currentIndex: nil,
        previous2: nil,
        previous1: nil,
        current: nil,
        next1: nil,
        next2: nil,
        lineProgress: 0,
        transitionProgress: 0,
        karaokeEligible: false
    )
}

public struct LyricsSyncEngine: Sendable {
    public var transitionWindow: TimeInterval

    public init(transitionWindow: TimeInterval = 0.55) {
        self.transitionWindow = max(0.05, transitionWindow)
    }

    /// A positive user offset delays the lyrics; a negative value advances them.
    public func frame(
        for document: LyricsDocument?,
        playbackPosition: TimeInterval,
        userOffset: TimeInterval = 0
    ) -> LyricFrame {
        guard let lines = document?.lines, !lines.isEmpty else { return .empty }
        let effectivePosition = max(0, playbackPosition - userOffset)
        let index = currentIndex(in: lines, at: effectivePosition)

        guard let index else {
            return LyricFrame(
                currentIndex: nil,
                previous2: nil,
                previous1: nil,
                current: nil,
                next1: line(at: 0, in: lines),
                next2: line(at: 1, in: lines),
                lineProgress: 0,
                transitionProgress: 0
            )
        }

        let current = lines[index]
        let next = line(at: index + 1, in: lines)
        let end = next?.timestamp ?? max(current.timestamp + 4, document?.duration ?? current.timestamp + 4)
        let span = max(0.001, end - current.timestamp)
        let lineProgress = min(max(0, (effectivePosition - current.timestamp) / span), 1)
        let remaining = end - effectivePosition
        let transition = next == nil ? 0 : min(max(0, 1 - remaining / transitionWindow), 1)
        let karaokeEligible = next.map { following in
            !current.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && following.timestamp > current.timestamp + 0.05
        } ?? false

        return LyricFrame(
            currentIndex: index,
            previous2: line(at: index - 2, in: lines),
            previous1: line(at: index - 1, in: lines),
            current: current,
            next1: next,
            next2: line(at: index + 2, in: lines),
            lineProgress: lineProgress,
            transitionProgress: transition,
            karaokeEligible: karaokeEligible
        )
    }

    private func currentIndex(in lines: [LyricLine], at position: TimeInterval) -> Int? {
        guard position >= lines[0].timestamp else { return nil }
        var lower = 0
        var upper = lines.count - 1
        var result = 0

        while lower <= upper {
            let middle = lower + (upper - lower) / 2
            if lines[middle].timestamp <= position {
                result = middle
                lower = middle + 1
            } else {
                upper = middle - 1
            }
        }
        return result
    }

    private func line(at index: Int, in lines: [LyricLine]) -> LyricLine? {
        guard lines.indices.contains(index) else { return nil }
        return lines[index]
    }
}
