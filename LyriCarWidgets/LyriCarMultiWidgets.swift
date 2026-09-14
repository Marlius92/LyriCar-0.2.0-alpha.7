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
        .configurationDisplayName("LyriCar · Superiore")
        .description("Le tre righe appena cantate, senza controlli o tempi.")
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
        .description("Riga corrente grande e due righe future, solo testo.")
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
        .description("Le due righe successive, solo testo.")
        .supportedFamilies([.systemSmall])
    }
}

private struct LyriCarBeforeWidgetView: View {
    let state: LyriCarWidgetSharedState

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            line(state.previous3, size: 11, opacity: 0.24, lines: 2)
            line(state.previous2, size: 13, opacity: 0.44, lines: 2)
            line(state.previous1, size: 16, opacity: 0.72, lines: 2, weight: .semibold)
            Spacer(minLength: 0)
        }
        .padding(11)
    }
}

private struct LyriCarCurrentWidgetView: View {
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

            line(state.next1, size: 13, opacity: 0.52, lines: 2, weight: .medium)
            line(state.next2, size: 11, opacity: 0.26, lines: 2)
            Spacer(minLength: 0)
        }
        .padding(10)
    }
}

private struct LyriCarAfterWidgetView: View {
    let state: LyriCarWidgetSharedState

    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            line(state.next1, size: 17, opacity: 0.68, lines: 3, weight: .semibold)
            line(state.next2, size: 13, opacity: 0.34, lines: 3)
            Spacer(minLength: 0)
        }
        .padding(12)
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
            .minimumScaleFactor(0.62)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
