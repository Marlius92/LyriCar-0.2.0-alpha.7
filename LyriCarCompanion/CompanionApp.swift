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
