import LyriCarCore
import SwiftUI

@main
struct LyriCarCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            CompanionStatusView()
        }
    }
}

private struct CompanionStatusView: View {
    @State private var state: LyriCarWidgetSharedState? = LyriCarWidgetSharedStore.load()
    @State private var diagnostics = LyriCarWidgetSharedStore.diagnostics()
    @State private var now = Date()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text("LyriComp")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text("Secondo widget CarPlay")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if let state {
                        liveLyricsCard(state)
                    } else {
                        Text("Apri LyriCar principale, collega Spotify e avvia un brano. LyriComp leggerà automaticamente gli stessi testi.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    diagnosticsCard
                    signingDetailsCard

                    Text("LyriComp usa gli identificatori realmente presenti dopo la firma. Se Signulous ha riscritto App Group o Keychain, verranno rilevati automaticamente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
            }
        }
        .task {
            while !Task.isCancelled {
                state = LyriCarWidgetSharedStore.load()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        .task {
            while !Task.isCancelled {
                now = Date()
                diagnostics = LyriCarWidgetSharedStore.diagnostics()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func liveLyricsCard(_ rawState: LyriCarWidgetSharedState) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !rawState.isPlaying)) { timeline in
            let state = locallyAdvanced(rawState, at: timeline.date)
            VStack(spacing: 10) {
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)

                Text(state.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if isWaitingForLyrics(state) {
                    ProgressView("Ricerca del testo sincronizzato…")
                        .tint(.white)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.vertical, 18)
                } else {
                    if !state.previous1.isEmpty {
                        Text(state.previous1)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.24))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }

                    karaokeText(
                        state.current,
                        progress: karaokeProgress(for: state, at: timeline.date)
                    )
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.54)
                    .frame(maxWidth: .infinity)
                    .shadow(
                        color: .white.opacity(
                            state.karaokeEligible
                                ? 0.20 * (karaokeProgress(for: state, at: timeline.date) ?? 0)
                                : 0.10
                        ),
                        radius: 7
                    )

                    if !state.next1.isEmpty {
                        Text(state.next1)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.46))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }

                    if !state.next2.isEmpty {
                        Text(state.next2)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.24))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func locallyAdvanced(
        _ state: LyriCarWidgetSharedState,
        at date: Date
    ) -> LyriCarWidgetSharedState {
        guard state.isPlaying,
              !state.next1.isEmpty,
              let nextStart = state.nextLineStartsAt,
              state.estimatedPosition(at: date) >= nextStart else {
            return state
        }

        return LyriCarWidgetSharedState(
            title: state.title,
            artist: state.artist,
            previous3: state.previous2,
            previous2: state.previous1,
            previous1: state.current,
            current: state.next1,
            next1: state.next2,
            next2: "",
            position: state.estimatedPosition(at: date),
            duration: state.duration,
            isPlaying: state.isPlaying,
            capturedAt: date,
            currentLineStartedAt: nextStart,
            nextLineStartsAt: nil,
            karaokeEligible: false
        )
    }

    private func karaokeProgress(
        for state: LyriCarWidgetSharedState,
        at date: Date
    ) -> Double? {
        guard state.karaokeEligible,
              let start = state.currentLineStartedAt,
              let end = state.nextLineStartsAt,
              end > start else {
            return nil
        }
        let position = state.estimatedPosition(at: date)
        return min(max((position - start) / (end - start), 0), 1)
    }

    private func karaokeText(_ value: String, progress: Double?) -> Text {
        guard let progress else {
            return Text(value).foregroundColor(.white)
        }

        let characters = Array(value)
        guard !characters.isEmpty else {
            return Text(value).foregroundColor(.white)
        }

        let exact = min(max(progress, 0), 1) * Double(characters.count)
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

    private func isWaitingForLyrics(_ state: LyriCarWidgetSharedState) -> Bool {
        state.current
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveContains("in attesa del testo")
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            statusLabel(
                diagnostics.appGroupAvailable,
                success: "App Group disponibile",
                failure: "App Group non disponibile"
            )

            statusLabel(
                diagnostics.keychainAccessAvailable,
                success: "Keychain condiviso disponibile",
                failure: "Keychain condiviso non disponibile"
            )

            if let state {
                let age = max(0, now.timeIntervalSince(state.capturedAt))
                Label("Stato condiviso ricevuto · \(age.formatted(.number.precision(.fractionLength(0)))) s fa", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Nessuno stato condiviso ricevuto", systemImage: "xmark.circle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.footnote)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var signingDetailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Firma effettiva")
                .font(.headline)
                .foregroundStyle(.white)

            detail("Team", diagnostics.teamIdentifier ?? "—")
            detail("Application ID", diagnostics.applicationIdentifier ?? "—")
            detail("App Group usato", diagnostics.effectiveAppGroup ?? "nessuno")
            detail("Keychain usato", diagnostics.effectiveKeychainGroup ?? "nessuno")
            detail(
                "App Group firmati",
                diagnostics.signedAppGroups.isEmpty
                    ? "nessuno"
                    : diagnostics.signedAppGroups.joined(separator: "\n")
            )
            detail(
                "Keychain group firmati",
                diagnostics.signedKeychainGroups.isEmpty
                    ? "nessuno"
                    : diagnostics.signedKeychainGroups.joined(separator: "\n")
            )
        }
        .font(.caption)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.white)
                .textSelection(.enabled)
        }
    }

    private func statusLabel(
        _ available: Bool,
        success: String,
        failure: String
    ) -> some View {
        Label(
            available ? success : failure,
            systemImage: available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        )
        .foregroundStyle(available ? .green : .orange)
    }
}
