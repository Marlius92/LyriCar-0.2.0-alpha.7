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
        completion(LyriCarWidgetEntry(date: Date(), state: LyriCarWidgetSharedStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyriCarWidgetEntry>) -> Void) {
        let now = Date()
        let state = LyriCarWidgetSharedStore.load() ?? .placeholder
        let entry = LyriCarWidgetEntry(date: now, state: state)
        // The app asks WidgetCenter for a reload at lyric/track transitions. This
        // fallback refresh ensures stale state eventually recovers even if iOS
        // suspended the app before it could signal the extension.
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

struct LyriCarBeforeWidget: Widget {
    static let kind = "LyriCar.Context.Before"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LyriCarWidgetProvider()) { entry in
            LyriCarBeforeWidgetView(state: entry.state)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("LyriCar · Prima")
        .description("Le righe appena cantate e il contesto della riga corrente.")
        .supportedFamilies([.systemSmall])
    }
}

struct LyriCarCurrentWidget: Widget {
    static let kind = "LyriCar.Current"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LyriCarWidgetProvider()) { entry in
            LyriCarCurrentWidgetView(state: entry.state)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("LyriCar · Corrente")
        .description("La riga corrente grande con progressione del brano.")
        .supportedFamilies([.systemSmall])
    }
}

struct LyriCarAfterWidget: Widget {
    static let kind = "LyriCar.Context.After"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LyriCarWidgetProvider()) { entry in
            LyriCarAfterWidgetView(state: entry.state)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("LyriCar · Dopo")
        .description("Le prossime righe e il tempo restante del brano.")
        .supportedFamilies([.systemSmall])
    }
}

private struct LyriCarBeforeWidgetView: View {
    let state: LyriCarWidgetSharedState

    var body: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 0)
            line(state.previous2, size: 11, opacity: 0.28, lines: 2)
            line(state.previous1, size: 14, opacity: 0.52, lines: 2)
            line(state.current, size: 17, opacity: 0.82, lines: 2, weight: .semibold)
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

private struct LyriCarCurrentWidgetView: View {
    let state: LyriCarWidgetSharedState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 1) {
                Text(state.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(state.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(state.current)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(4)
                .minimumScaleFactor(0.58)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            if state.isPlaying, state.duration > 0 {
                ProgressView(timerInterval: state.playbackInterval, countsDown: false)
                    .tint(.white)
            } else {
                ProgressView(value: state.duration > 0 ? state.position / state.duration : 0)
                    .tint(.white)
            }
        }
        .padding(12)
    }
}

private struct LyriCarAfterWidgetView: View {
    let state: LyriCarWidgetSharedState

    var body: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 0)
            line(state.next1, size: 17, opacity: 0.66, lines: 2, weight: .semibold)
            line(state.next2, size: 12, opacity: 0.30, lines: 2)
            Spacer(minLength: 0)
            HStack {
                Text("restano")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if state.isPlaying, state.duration > 0 {
                    Text(timerInterval: state.remainingInterval, countsDown: true)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(remainingText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }

    private var remainingText: String {
        let seconds = max(0, Int(state.duration - state.position))
        return String(format: "-%d:%02d", seconds / 60, seconds % 60)
    }
}

@ViewBuilder
private func line(
    _ text: String,
    size: CGFloat,
    opacity: Double,
    lines: Int,
    weight: Font.Weight = .regular
) -> some View {
    if !text.isEmpty {
        Text(text)
            .font(.system(size: size, weight: weight, design: .rounded))
            .foregroundStyle(.white.opacity(opacity))
            .lineLimit(lines)
            .minimumScaleFactor(0.68)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
