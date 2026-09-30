import ActivityKit
import Foundation
import LyriCarCore

/// Keeps the Live Activity current without attempting one update per rendered frame.
/// ActivityKit is intended for glanceable state changes, so LyriCar updates on track,
/// lyric-line, playback-state and coarse progress changes.
@MainActor
final class LyriCarActivityManager {
    private struct UpdateSignature: Equatable {
        let trackKey: String
        let previous2: String
        let previous1: String
        let currentLine: String
        let next1: String
        let next2: String
        let isPlaying: Bool
        let positionBucket: Int
    }

    private var activity: Activity<LyriCarActivityAttributes>?
    private var lastSignature: UpdateSignature?
    private var lastState: LyriCarActivityAttributes.ContentState?

    init() {
        activity = Activity<LyriCarActivityAttributes>.activities.first
        lastState = activity?.content.state
    }

    /// Starts the Live Activity while LyriCar is still in the foreground.
    /// ActivityKit can update an existing activity from background execution,
    /// but starting a brand-new one is normally restricted once the app leaves
    /// the foreground. Keeping a lightweight waiting activity ready lets the
    /// user switch to Spotify and CarPlay without losing the presentation.
    func prepare(enabled: Bool) async {
        guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
            await end()
            return
        }
        guard activity == nil else { return }

        let state = LyriCarActivityAttributes.ContentState(
            title: "LyriCar",
            artist: "Spotify",
            previous2: "",
            previousLine: "",
            currentLine: "Avvia un brano in Spotify",
            nextLine: "I testi compariranno qui automaticamente",
            next2: "",
            position: 0,
            duration: 1,
            isPlaying: false,
            capturedAt: Date()
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            activity = try Activity.request(
                attributes: LyriCarActivityAttributes(sessionID: UUID().uuidString),
                content: content,
                pushType: nil
            )
            lastState = state
            lastSignature = nil
        } catch {
            return
        }
    }

    func update(
        playback: PlaybackSnapshot,
        frame: LyricFrame,
        enabled: Bool
    ) async {
        guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
            await end()
            return
        }

        let position = playback.estimatedPosition()
        let previous2 = frame.previous2?.text ?? ""
        let previous1 = frame.previous1?.text ?? ""
        let currentLine = frame.current?.text ?? (frame.next1?.text ?? "In attesa del testo…")
        let next1 = frame.next1?.text ?? ""
        let next2 = frame.next2?.text ?? ""
        let bucketSize: TimeInterval = playback.isPlaying ? 12 : 1
        let signature = UpdateSignature(
            trackKey: playback.track.stableCacheKey,
            previous2: previous2,
            previous1: previous1,
            currentLine: currentLine,
            next1: next1,
            next2: next2,
            isPlaying: playback.isPlaying,
            positionBucket: Int(position / bucketSize)
        )

        if activity != nil, signature == lastSignature { return }

        let state = LyriCarActivityAttributes.ContentState(
            title: playback.track.title,
            artist: playback.track.displayArtist,
            previous2: previous2,
            previousLine: previous1,
            currentLine: currentLine,
            nextLine: next1,
            next2: next2,
            position: position,
            duration: playback.track.duration,
            isPlaying: playback.isPlaying,
            capturedAt: Date()
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(30))

        if let activity {
            await activity.update(content)
        } else {
            do {
                activity = try Activity.request(
                    attributes: LyriCarActivityAttributes(sessionID: UUID().uuidString),
                    content: content,
                    pushType: nil
                )
            } catch {
                // The main iPhone renderer remains functional when Live Activities are disabled.
                return
            }
        }

        lastState = state
        lastSignature = signature
    }

    func end() async {
        guard let activity else { return }
        let state = lastState ?? activity.content.state
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .immediate
        )
        self.activity = nil
        lastState = nil
        lastSignature = nil
    }
}
