import Foundation
import LyriCarCore
import WidgetKit

/// Bridges the live LyriCar playback state into the WidgetKit extension.
/// Widget timelines are reloaded only when meaningful text/playback state changes;
/// the song progress bar itself uses a system timer interval and stays fluid without
/// requesting one widget reload per second.
@MainActor
final class LyriCarWidgetStateManager {
    private struct Signature: Equatable {
        let track: String
        let previous1: String
        let current: String
        let next1: String
        let next2: String
        let isPlaying: Bool
    }

    private var lastSignature: Signature?

    func update(playback: PlaybackSnapshot, frame: LyricFrame) {
        let current = frame.current?.text ?? (frame.next1?.text ?? "In attesa del testo…")
        let state = LyriCarWidgetSharedState(
            title: playback.track.title,
            artist: playback.track.displayArtist,
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
        LyriCarWidgetSharedStore.save(state)

        let signature = Signature(
            track: playback.track.stableCacheKey,
            previous1: state.previous1,
            current: state.current,
            next1: state.next1,
            next2: state.next2,
            isPlaying: state.isPlaying
        )
        guard signature != lastSignature else { return }
        lastSignature = signature

        for kind in LyriCarWidgetKinds.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }

    func clear() {
        LyriCarWidgetSharedStore.clear()
        lastSignature = nil
        for kind in LyriCarWidgetKinds.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}

private enum LyriCarWidgetKinds {
    static let all = [
        "LyriCar.Context.Before",
        "LyriCar.Current",
        "LyriCar.Context.After"
    ]
}
