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
    @State private var now = Date()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text("LyriCar Companion")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text("Secondo widget CarPlay")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if let state {
                        VStack(spacing: 8) {
                            Text(state.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text(state.current)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        Text("Apri LyriCar principale, collega Spotify e avvia un brano. La Companion leggerà automaticamente gli stessi testi.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    diagnosticsCard

                    Text("Non collegare Spotify anche qui: la Companion usa lo stato condiviso di LyriCar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
            }
        }
        .task {
            while !Task.isCancelled {
                now = Date()
                state = LyriCarWidgetSharedStore.load()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(
                LyriCarWidgetSharedStore.appGroupAvailable ? "App Group disponibile" : "App Group non disponibile",
                systemImage: LyriCarWidgetSharedStore.appGroupAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(LyriCarWidgetSharedStore.appGroupAvailable ? .green : .orange)

            if let state {
                let age = max(0, now.timeIntervalSince(state.capturedAt))
                Label("Stato condiviso ricevuto · \(age.formatted(.number.precision(.fractionLength(0)))) s fa", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
            } else {
                Label("Nessuno stato condiviso ricevuto", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
            }

            if !LyriCarWidgetSharedStore.appGroupAvailable {
                Text("La firma iOS non ha concesso l’App Group. Firma LyriCar e LyriCar Companion con lo stesso certificato/profilo e senza cambiare i bundle ID; altrimenti i due widget non possono condividere brano e testi.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .font(.footnote)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
