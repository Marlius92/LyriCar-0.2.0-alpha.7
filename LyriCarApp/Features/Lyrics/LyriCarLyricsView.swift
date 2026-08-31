import LyriCarCore
import SwiftUI

struct LyriCarLyricsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: LyriCarSettings
    let showsSettingsButton: Bool

    init(model: AppModel, showsSettingsButton: Bool = true) {
        self.model = model
        self.showsSettingsButton = showsSettingsButton
        _settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            GeometryReader { geometry in
                let position = model.playback?.estimatedPosition(at: timeline.date) ?? 0
                ZStack {
                    Color.black.ignoresSafeArea()

                    header(in: geometry.size)

                    PerspectiveLyricsView(
                        document: model.lyrics,
                        frame: model.frame(at: timeline.date),
                        fontScale: settings.fontScale,
                        fadeStrength: settings.fadeStrength
                    )
                    .frame(width: geometry.size.width * 0.94, height: geometry.size.height * 0.52)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.48)

                    emptyState(in: geometry.size)

                    if let playback = model.playback {
                        progressArea(
                            playback: playback,
                            position: position,
                            size: geometry.size
                        )
                    }

                    controls(in: geometry.size)

                    if showsSettingsButton {
                        settingsButton(in: geometry.size)
                    }
                }
                .contentShape(Rectangle())
            }
        }
        .background(Color.black)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func header(in size: CGSize) -> some View {
        VStack(spacing: max(2, size.height * 0.006)) {
            HStack(spacing: 9) {
                Text(model.playback?.track.title ?? "LyriCar")
                    .font(.system(size: max(17, min(30, size.height * 0.045)), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if model.isDemoMode {
                    Text("DEMO")
                        .font(.system(size: max(9, min(12, size.height * 0.018)), weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white, in: Capsule())
                }
            }
            Text(model.playback?.track.displayArtist ?? "Testi sincronizzati per Spotify")
                .font(.system(size: max(11, min(18, size.height * 0.026)), weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size.width * 0.72)
        .position(x: size.width / 2, y: max(38, size.height * 0.095))
    }

    @ViewBuilder
    private func emptyState(in size: CGSize) -> some View {
        if model.playback == nil {
            VStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: min(42, size.height * 0.08), weight: .medium))
                Text("Apri Spotify e avvia un brano")
                    .font(.system(size: min(25, size.height * 0.046), weight: .semibold, design: .rounded))
                if !model.statusMessage.isEmpty {
                    Text(model.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(.white.opacity(0.72))
            .frame(width: size.width * 0.75)
            .position(x: size.width / 2, y: size.height * 0.48)
        } else {
            switch model.lyricsState {
            case .loading:
                ProgressView("Ricerca del testo sincronizzato…")
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.72))
                    .position(x: size.width / 2, y: size.height * 0.48)
            case .instrumental:
                statusLabel("Brano strumentale", size: size)
            case .unavailable:
                statusLabel("Testo sincronizzato non disponibile", size: size)
            case .failed(let message):
                statusLabel("Impossibile caricare il testo\n\(message)", size: size)
            case .idle, .available:
                EmptyView()
            }
        }
    }

    private func statusLabel(_ value: String, size: CGSize) -> some View {
        Text(value)
            .font(.system(size: min(24, size.height * 0.044), weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.64))
            .frame(width: size.width * 0.76)
            .position(x: size.width / 2, y: size.height * 0.48)
    }

    private func progressArea(
        playback: PlaybackSnapshot,
        position: TimeInterval,
        size: CGSize
    ) -> some View {
        VStack(spacing: max(7, size.height * 0.013)) {
            HStack(spacing: 12) {
                Text(DurationFormatting.clock(position))
                    .monospacedDigit()
                    .frame(width: max(48, size.width * 0.085), alignment: .leading)
                LyriCarProgressBar(
                    progress: playback.track.duration > 0 ? position / playback.track.duration : 0
                )
                Text(DurationFormatting.remaining(position: position, duration: playback.track.duration))
                    .monospacedDigit()
                    .frame(width: max(48, size.width * 0.085), alignment: .trailing)
            }
            .font(.system(size: max(11, min(17, size.height * 0.026)), weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))
        }
        .frame(width: size.width * 0.84)
        .position(x: size.width / 2, y: size.height * 0.79)
    }

    private func controls(in size: CGSize) -> some View {
        HStack(spacing: max(38, size.width * 0.075)) {
            controlButton(symbol: "backward.end.fill", accessibility: "Brano precedente") {
                model.previousTrack()
            }
            controlButton(
                symbol: model.playback?.isPlaying == true ? "pause.fill" : "play.fill",
                emphasized: true,
                accessibility: model.playback?.isPlaying == true ? "Pausa" : "Riproduci"
            ) {
                model.togglePlayPause()
            }
            controlButton(symbol: "forward.end.fill", accessibility: "Brano successivo") {
                model.nextTrack()
            }
        }
        .disabled(model.playback == nil)
        .opacity(model.playback == nil ? 0.32 : 1)
        .position(x: size.width / 2, y: size.height * 0.91)
    }

    private func controlButton(
        symbol: String,
        emphasized: Bool = false,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: emphasized ? 25 : 20, weight: .semibold))
                .foregroundStyle(emphasized ? .black : .white)
                .frame(width: emphasized ? 58 : 46, height: emphasized ? 58 : 46)
                .background(emphasized ? Color.white : Color.white.opacity(0.09), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }

    private func settingsButton(in size: CGSize) -> some View {
        Button {
            model.showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .position(x: size.width - 34, y: 34)
        .accessibilityLabel("Impostazioni")
    }
}

private struct PerspectiveLyricsView: View {
    let document: LyricsDocument?
    let frame: LyricFrame
    let fontScale: Double
    let fadeStrength: Double

    var body: some View {
        GeometryReader { geometry in
            if let lines = document?.lines, !lines.isEmpty {
                let baseIndex = frame.currentIndex ?? -1
                let transition = transitionCurve(frame.transitionProgress)
                let lower = max(0, baseIndex - 3)
                let upper = min(lines.count - 1, baseIndex + 4)

                ZStack {
                    ForEach(Array(lower...upper), id: \.self) { index in
                        let relative = Double(index - baseIndex) - transition
                        let metrics = metrics(for: relative, size: geometry.size)
                        let sourceText = lines[index].text.isEmpty ? "♪" : lines[index].text
                        let isKaraokeLine = index == baseIndex && frame.karaokeEligible && !lines[index].text.isEmpty
                        let isFutureKaraokeLine = index > baseIndex && karaokeEligible(at: index, in: lines)
                        lyricText(
                            sourceText,
                            karaokeProgress: isKaraokeLine ? frame.lineProgress : nil,
                            futureKaraokePreview: isFutureKaraokeLine
                        )
                            .font(.system(
                                size: metrics.fontSize,
                                weight: abs(relative) < 0.55 ? .bold : .semibold,
                                design: .rounded
                            ))
                            .opacity(metrics.opacity)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.52)
                            .frame(
                                width: geometry.size.width * metrics.widthFactor,
                                height: metrics.rowHeight
                            )
                            .rotation3DEffect(
                                .degrees(metrics.rotation),
                                axis: (x: 1, y: 0, z: 0),
                                anchor: .center,
                                perspective: 0.55
                            )
                            .shadow(
                                color: karaokeShadowColor(
                                    isCurrent: isKaraokeLine,
                                    isFuture: isFutureKaraokeLine,
                                    progress: frame.lineProgress,
                                    relative: relative
                                ),
                                radius: isKaraokeLine ? 7 : 13
                            )
                            .position(x: geometry.size.width / 2, y: metrics.y)
                            .accessibilityHidden(abs(relative) > 0.6)
                    }
                }
                .clipped()
            }
        }
    }

    /// Builds the active lyric as a true character-by-character highlight.
    /// If `karaokeProgress` is nil the text is rendered exactly as before.
    private func lyricText(
        _ value: String,
        karaokeProgress: Double?,
        futureKaraokePreview: Bool = false
    ) -> Text {
        guard let karaokeProgress else {
            return Text(value).foregroundColor(
                futureKaraokePreview ? .white.opacity(0.30) : .white
            )
        }

        let characters = Array(value)
        guard !characters.isEmpty else {
            return Text(value).foregroundColor(.white)
        }

        let progress = min(max(karaokeProgress, 0), 1)
        let exact = progress * Double(characters.count)
        let completedCount = min(characters.count, Int(floor(exact)))
        let partial = exact - Double(completedCount)

        let completed = String(characters.prefix(completedCount))
        let current = completedCount < characters.count ? String(characters[completedCount]) : ""
        let remainingStart = min(characters.count, completedCount + (current.isEmpty ? 0 : 1))
        let remaining = String(characters.dropFirst(remainingStart))

        var result = Text(completed).foregroundColor(.white)
        if !current.isEmpty {
            result = result + Text(current)
                .foregroundColor(.white.opacity(0.30 + 0.70 * partial))
        }
        if !remaining.isEmpty {
            result = result + Text(remaining)
                .foregroundColor(.white.opacity(0.30))
        }
        return result
    }


    private func karaokeEligible(at index: Int, in lines: [LyricLine]) -> Bool {
        guard lines.indices.contains(index), lines.indices.contains(index + 1) else { return false }
        let current = lines[index]
        let next = lines[index + 1]
        return !current.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && next.timestamp > current.timestamp + 0.05
    }

    private func karaokeShadowColor(
        isCurrent: Bool,
        isFuture: Bool,
        progress: Double,
        relative: Double
    ) -> Color {
        if isFuture { return .clear }
        if isCurrent {
            // No white flash when a dark future line becomes current: the glow
            // grows together with the karaoke sweep from exactly zero.
            let glow = min(max(progress, 0), 1)
            return .white.opacity(0.24 * glow)
        }
        return abs(relative) < 0.55 ? .white.opacity(0.13) : .clear
    }

    private func metrics(for relative: Double, size: CGSize) -> LineMetrics {
        let absolute = abs(relative)
        let center = size.height / 2
        let signed = relative < 0 ? -1.0 : 1.0
        let offsetRatio: Double
        if absolute <= 1 {
            offsetRatio = interpolate(0, 0.27, absolute)
        } else if absolute <= 2 {
            offsetRatio = interpolate(0.27, 0.42, absolute - 1)
        } else {
            offsetRatio = interpolate(0.42, 0.54, min(1, absolute - 2))
        }
        let distance = size.height * offsetRatio
        let scale: Double
        let rawOpacity: Double

        if absolute <= 1 {
            scale = interpolate(1.0, 0.70, absolute)
            rawOpacity = interpolate(1.0, 0.60, absolute)
        } else if absolute <= 2 {
            scale = interpolate(0.70, 0.49, absolute - 1)
            rawOpacity = interpolate(0.60, 0.22, absolute - 1)
        } else {
            scale = max(0.36, 0.49 - (absolute - 2) * 0.12)
            rawOpacity = max(0, 0.22 - (absolute - 2) * 0.20)
        }

        let baseFont = min(size.width * 0.058, size.height * 0.13) * fontScale
        let opacity = pow(max(0, rawOpacity), max(0.35, fadeStrength))
        let rowHeightFactor: Double
        if absolute <= 1 {
            rowHeightFactor = interpolate(0.25, 0.18, absolute)
        } else {
            rowHeightFactor = interpolate(0.18, 0.13, min(1, absolute - 1))
        }
        return LineMetrics(
            fontSize: max(11, baseFont * scale),
            opacity: opacity,
            widthFactor: max(0.80, 0.90 - min(absolute, 3) * 0.03),
            rowHeight: size.height * rowHeightFactor,
            rotation: max(-18, min(18, relative * 7.5)),
            y: center + signed * distance
        )
    }

    private func interpolate(_ start: Double, _ end: Double, _ amount: Double) -> Double {
        start + (end - start) * min(max(amount, 0), 1)
    }

    private func transitionCurve(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        let smooth = clamped * clamped * (3 - 2 * clamped)
        // A small linear component prevents long transitions from appearing
        // stationary at their endpoints while preserving soft acceleration.
        return 0.20 * clamped + 0.80 * smooth
    }

    private struct LineMetrics {
        let fontSize: Double
        let opacity: Double
        let widthFactor: Double
        let rowHeight: Double
        let rotation: Double
        let y: Double
    }
}

private struct LyriCarProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let value = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16))
                Capsule()
                    .fill(Color.white.opacity(0.93))
                    .frame(width: geometry.size.width * value)
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .offset(x: max(-1, geometry.size.width * value - 6))
            }
        }
        .frame(height: 12)
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100)) percento")
    }
}
