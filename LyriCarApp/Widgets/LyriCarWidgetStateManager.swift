import Foundation
import LyriCarCore
import WidgetKit

/// Bridges the live LyriCar playback state into WidgetKit.
@MainActor
final class LyriCarWidgetStateManager {
    private struct Signature: Equatable {
        let track: String
        let previous3: String
        let previous2: String
        let previous1: String
        let current: String
        let next1: String
        let next2: String
        let isPlaying: Bool
    }

    private var lastSignature: Signature?

    @discardableResult
    func update(playback: PlaybackSnapshot, frame: LyricFrame) -> String {
        let current = frame.current?.text ?? (frame.next1?.text ?? "In attesa del testo…")
        let state = LyriCarWidgetSharedState(
            title: playback.track.title,
            artist: playback.track.displayArtist,
            previous3: frame.previous3?.text ?? "",
            previous2: frame.previous2?.text ?? "",
            previous1: frame.previous1?.text ?? "",
            current: current,
            next1: frame.next1?.text ?? "",
            next2: frame.next2?.text ?? "",
            position: playback.estimatedPosition(),
            duration: playback.track.duration,
            isPlaying: playback.isPlaying,
            capturedAt: Date(),
            currentLineStartedAt: frame.current?.timestamp,
            nextLineStartsAt: frame.next1?.timestamp,
            karaokeEligible: frame.karaokeEligible
        )
        let transport = LyriCarWidgetSharedStore.save(state)

        let signature = Signature(
            track: playback.track.stableCacheKey,
            previous3: state.previous3,
            previous2: state.previous2,
            previous1: state.previous1,
            current: state.current,
            next1: state.next1,
            next2: state.next2,
            isPlaying: state.isPlaying
        )
        guard signature != lastSignature else { return transport.displayName }
        lastSignature = signature

        for kind in LyriCarWidgetKinds.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        return transport.displayName
    }

    @discardableResult
    func clear() -> String {
        let transport = LyriCarWidgetSharedStore.clear()
        lastSignature = nil
        for kind in LyriCarWidgetKinds.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        return transport.displayName
    }
}

private enum LyriCarWidgetKinds {
    static let all = [
        "LyriCar.Context.Before",
        "LyriCar.Current",
        "LyriCar.Context.After",
        "LyriCar.Companion.Lower"
    ]
}
