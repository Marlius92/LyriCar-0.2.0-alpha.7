import LyriCarCore
import SwiftUI
import WidgetKit

private struct LyriCarWidgetEntry: TimelineEntry {
    let date: Date
    let state: LyriCarWidgetSharedState
}

private struct LyriCarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyriCarWidgetEntry {
        LyriCarWidgetEntry(date: Date(), state: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (LyriCarWidgetEntry) -> Void) {
        completion(
            LyriCarWidgetEntry(
                date: Date(),
                state: LyriCarWidgetSharedStore.load() ?? .placeholder
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyriCarWidgetEntry>) -> Void) {
        let now = Date()
        let state = LyriCarWidgetSharedStore.load() ?? .placeholder
        let entry = LyriCarWidgetEntry(date: now, state: state)
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

struct LyriCarLyricsWidget: Widget {
    static let kind = "LyriCar.Lyrics"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LyriCarWidgetProvider()) { entry in
            LyriCarLyricsWidgetView(state: entry.state)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("LyriCar · Lyrics")
        .description("Riga precedente, attuale e successiva.")
        .supportedFamilies([.systemSmall])
    }
}

private struct LyriCarLyricsWidgetView: View {
    let state: LyriCarWidgetSharedState

    var body: some View {
        VStack(spacing: 9) {
            Spacer(minLength: 0)

            lyric(
                state.previous1,
                size: 13,
                opacity: 0.46,
                weight: .medium,
                lines: 2
            )

            Text(state.current)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.52)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .contentTransition(.opacity)

            lyric(
                state.next1,
                size: 13,
                opacity: 0.46,
                weight: .medium,
                lines: 2
            )

            Spacer(minLength: 0)
        }
        .padding(11)
        .animation(.easeInOut(duration: 0.28), value: state.current)
    }

    @ViewBuilder
    private func lyric(
        _ text: String,
        size: CGFloat,
        opacity: Double,
        weight: Font.Weight,
        lines: Int
    ) -> some View {
        if !text.isEmpty {
            Text(text)
                .font(.system(size: size, weight: weight, design: .rounded))
                .foregroundStyle(.white.opacity(opacity))
                .lineLimit(lines)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .contentTransition(.opacity)
        }
    }
}
