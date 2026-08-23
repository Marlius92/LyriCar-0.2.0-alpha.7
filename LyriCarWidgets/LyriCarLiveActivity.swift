import ActivityKit
import Foundation
import LyriCarCore
import SwiftUI
import WidgetKit

struct LyriCarLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyriCarActivityAttributes.self) { context in
            LyriCarActivityContent(context: context)
                .activityBackgroundTint(.black.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(time(context.state.position))
                        .font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        Text(context.state.currentLine)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        ProgressView(value: context.state.clampedProgress)
                    }
                }
            } compactLeading: {
                Image(systemName: "text.quote")
            } compactTrailing: {
                Text(context.state.isPlaying ? time(context.state.position) : "Pausa")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "text.quote")
            }
        }
        // CarPlay uses ActivityFamily.small. Without this declaration it falls
        // back to the very narrow Dynamic Island compact-leading/trailing views.
        .supplementalActivityFamilies([.small])
    }

    private func time(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct LyriCarActivityContent: View {
    @Environment(\.activityFamily) private var activityFamily
    let context: ActivityViewContext<LyriCarActivityAttributes>

    @ViewBuilder
    var body: some View {
        if activityFamily == .small {
            carPlaySmall
        } else {
            lockScreenMedium
        }
    }

    /// Compact, glanceable layout used by CarPlay Dashboard and Apple Watch.
    private var carPlaySmall: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .font(.caption.weight(.semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(context.state.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(context.state.artist)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text(context.state.currentLine)
                .font(.headline.weight(.bold))
                .lineLimit(3)
                .minimumScaleFactor(0.72)

            if !context.state.nextLine.isEmpty {
                Text(context.state.nextLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            activityProgress
                .tint(.primary)
        }
        .padding(12)
        .containerBackground(.black.opacity(0.92), for: .widget)
    }

    @ViewBuilder
    private var activityProgress: some View {
        if context.state.isPlaying, context.state.duration > 0 {
            ProgressView(timerInterval: context.state.playbackInterval, countsDown: false)
        } else {
            ProgressView(value: context.state.clampedProgress)
        }
    }

    private var lockScreenMedium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
            }

            if !context.state.previousLine.isEmpty {
                Text(context.state.previousLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .opacity(0.72)
                    .lineLimit(1)
            }

            Text(context.state.currentLine)
                .font(.title3.weight(.bold))
                .lineLimit(2)

            if !context.state.nextLine.isEmpty {
                Text(context.state.nextLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            activityProgress
                .tint(.primary)
        }
        .padding()
    }
}
