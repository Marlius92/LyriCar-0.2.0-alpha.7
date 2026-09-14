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
                        Text("Apri LyriCar principale, collega Spotify e avvia un brano. LyriComp leggerà automaticamente gli stessi testi.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    diagnosticsCard

                    Text("LyriComp prova prima l’App Group e poi il Keychain condiviso. Se almeno uno dei due canali resta disponibile dopo la firma, può ricevere lo stato di LyriCar.")
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
                diagnostics = LyriCarWidgetSharedStore.diagnostics()
                try? await Task.sleep(for: .seconds(1))
            }
        }
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

            if !diagnostics.appGroupAvailable && diagnostics.keychainAccessAvailable {
                Text("Signulous non ha concesso l’App Group, ma il fallback Keychain è disponibile. LyriComp può ancora funzionare se LyriCar riesce a scrivere nello stesso gruppo Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !diagnostics.appGroupAvailable && !diagnostics.keychainAccessAvailable {
                Text("La firma iOS non ha concesso né App Group né Keychain condiviso. In questa configurazione LyriCar e LyriComp non possono scambiarsi direttamente lo stato.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .font(.footnote)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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
