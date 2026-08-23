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
        let currentLine: String
        let nextLine: String
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
        let currentLine = frame.current?.text ?? (frame.next1?.text ?? "In attesa del testo…")
        let nextLine = frame.next1?.text ?? ""
        let bucketSize: TimeInterval = playback.isPlaying ? 12 : 1
        let signature = UpdateSignature(
            trackKey: playback.track.stableCacheKey,
            currentLine: currentLine,
            nextLine: nextLine,
            isPlaying: playback.isPlaying,
            positionBucket: Int(position / bucketSize)
        )

        if activity != nil, signature == lastSignature { return }

        let state = LyriCarActivityAttributes.ContentState(
            title: playback.track.title,
            artist: playback.track.displayArtist,
            previousLine: frame.previous1?.text ?? "",
            currentLine: currentLine,
            nextLine: nextLine,
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
