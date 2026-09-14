import LyriCarCore
import SwiftUI
import WidgetKit

private struct CompanionEntry: TimelineEntry {
    let date: Date
    let state: LyriCarWidgetSharedState
}

private struct CompanionProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompanionEntry {
        CompanionEntry(date: Date(), state: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CompanionEntry) -> Void) {
        completion(CompanionEntry(date: Date(), state: LyriCarWidgetSharedStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompanionEntry>) -> Void) {
        let now = Date()
        let state = LyriCarWidgetSharedStore.load() ?? .placeholder
        var entries = [CompanionEntry(date: now, state: state)]
        var refreshDate = now.addingTimeInterval(10)

        // Do not rely exclusively on WidgetKit granting an immediate timeline
        // reload from the other LyriCar host app. When the timestamp of the next
        // lyric is already known, pre-schedule that visual transition directly
        // in this widget's own timeline.
        if let transition = scheduledTransition(for: state, now: now) {
            entries.append(transition.entry)
            refreshDate = transition.entry.date.addingTimeInterval(1)
        }

        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func scheduledTransition(
        for state: LyriCarWidgetSharedState,
        now: Date
    ) -> (entry: CompanionEntry, delay: TimeInterval)? {
        guard state.isPlaying,
              !state.next1.isEmpty,
              let nextStart = state.nextLineStartsAt else {
            return nil
        }

        let position = state.estimatedPosition(at: now)
        guard nextStart > position else { return nil }

        let delay = nextStart - position
        // Very distant entries are better refreshed from the shared store first.
        guard delay <= 30 else { return nil }

        let transitionDate = now.addingTimeInterval(max(0.05, delay))
        let shifted = LyriCarWidgetSharedState(
            title: state.title,
            artist: state.artist,
            previous3: state.previous2,
            previous2: state.previous1,
            previous1: state.current,
            current: state.next1,
            next1: state.next2,
            next2: "",
            position: nextStart,
            duration: state.duration,
            isPlaying: state.isPlaying,
            capturedAt: transitionDate,
            currentLineStartedAt: nextStart,
            nextLineStartsAt: nil,
            karaokeEligible: false
        )

        return (CompanionEntry(date: transitionDate, state: shifted), delay)
    }
}

struct LyriCarCompanionLyricsWidget: Widget {
    static let kind = "LyriCar.Companion.Lower"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CompanionProvider()) { entry in
            CompanionLyricsView(state: entry.state)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("LyriCar Companion · Corrente")
        .description("Riga corrente grande e due righe future. Nessun controllo, barra o tempo.")
        .supportedFamilies([.systemSmall])
    }
}

private struct CompanionLyricsView: View {
    let state: LyriCarWidgetSharedState

    var body: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 0)

            Text(state.current)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(4)
                .minimumScaleFactor(0.50)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            lyric(state.next1, size: 13, opacity: 0.52, weight: .medium)
            lyric(state.next2, size: 11, opacity: 0.26)

            Spacer(minLength: 0)
        }
        .padding(10)
    }

    @ViewBuilder
    private func lyric(
        _ text: String,
        size: CGFloat,
        opacity: Double,
        weight: Font.Weight = .regular
    ) -> some View {
        if !text.isEmpty {
            Text(text)
                .font(.system(size: size, weight: weight, design: .rounded))
                .foregroundStyle(.white.opacity(opacity))
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}
