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
        let entry = CompanionEntry(date: now, state: state)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh(for: state, now: now))))
    }

    private func nextRefresh(for state: LyriCarWidgetSharedState, now: Date) -> Date {
        let position = state.estimatedPosition(at: now)
        if state.isPlaying,
           let nextStart = state.nextLineStartsAt,
           nextStart > position {
            let delay = min(max(nextStart - position + 0.08, 1.0), 15.0)
            return now.addingTimeInterval(delay)
        }
        return now.addingTimeInterval(10)
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
