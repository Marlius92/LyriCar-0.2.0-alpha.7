import CoreLocation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: LyriCarSettings
    @ObservedObject private var driveMode: DriveModeManager
    @ObservedObject private var spotifyConfiguration: SpotifyConfigurationStore
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel) {
        self.model = model
        _settings = ObservedObject(wrappedValue: model.settings)
        _driveMode = ObservedObject(wrappedValue: model.driveMode)
        _spotifyConfiguration = ObservedObject(wrappedValue: model.spotifyConfiguration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sincronizzazione") {
                    LabeledContent("Offset testo", value: signed(settings.lyricsOffset))
                    Slider(value: $settings.lyricsOffset, in: -5...5, step: 0.1)
                    Text("Valore positivo: il testo viene mostrato più tardi.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Aspetto") {
                    LabeledContent("Dimensione", value: String(format: "%.0f%%", settings.fontScale * 100))
                    Slider(value: $settings.fontScale, in: 0.78...1.30, step: 0.01)
                    LabeledContent("Dissolvenza", value: String(format: "%.2f", settings.fadeStrength))
                    Slider(value: $settings.fadeStrength, in: 0.55...1.75, step: 0.05)
                    LabeledContent("Transizione", value: String(format: "%.2f s", settings.transitionWindow))
                    Slider(value: $settings.transitionWindow, in: 0.25...1.20, step: 0.05)
                    Button("Ripristina aspetto") { settings.resetVisuals() }
                }

                Section("Auto e background") {
                    Toggle("Live Activity", isOn: Binding(
                        get: { settings.liveActivityEnabled },
                        set: { model.setLiveActivity($0) }
                    ))
                    Toggle("Drive Mode", isOn: Binding(
                        get: { settings.driveModeEnabled },
                        set: { model.setDriveMode($0) }
                    ))
                    Text("Drive Mode usa aggiornamenti di posizione a bassissima precisione solo per mantenere attiva la sincronizzazione. Le coordinate vengono ignorate, non salvate e non trasmesse.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if driveMode.authorizationStatus == .denied || driveMode.authorizationStatus == .restricted {
                        Text("Permesso posizione non disponibile. Abilitalo nelle Impostazioni di iOS per usare Drive Mode.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Spotify") {
                    if model.isDemoMode {
                        LabeledContent("Modalità", value: "Demo")
                        Button("Esci dalla demo") {
                            model.stopDemo()
                            dismiss()
                        }
                    } else {
                        LabeledContent("Client ID", value: spotifyConfiguration.maskedClientID)
                        Button("Apri Spotify") { model.openSpotify() }
                        Button("Scollega account") {
                            Task {
                                await model.disconnectSpotify(clearClientID: false)
                                dismiss()
                            }
                        }
                        Button("Rimuovi anche il Client ID", role: .destructive) {
                            Task {
                                await model.disconnectSpotify(clearClientID: true)
                                dismiss()
                            }
                        }
                    }
                }

                Section("Dati") {
                    Button("Elimina cache testi") {
                        Task { await model.clearLyricsCache() }
                    }
                }

                Section("Stato") {
                    LabeledContent("CarPlay", value: model.carPlayConnected ? "Collegato / rilevato" : "Non rilevato")
                    LabeledContent("Widget", value: model.widgetSharingStatus)
                    LabeledContent("Brano", value: model.playback?.track.title ?? "Nessun brano rilevato")
                    LabeledContent("Drive Mode", value: driveMode.isRunning ? "Attivo" : "Disattivo")
                    LabeledContent("Sorgente", value: model.isDemoMode ? "Demo locale" : "Spotify Web API")
                    if !model.statusMessage.isEmpty {
                        Text(model.statusMessage).font(.caption)
                    }
                }

                Section {
                    LabeledContent("Versione", value: versionLabel)
                }
            }
            .navigationTitle("Impostazioni")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }

    private var versionLabel: String {
        let marketing = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "15"
        return "\(marketing) (\(build))"
    }

    private func signed(_ value: Double) -> String {
        String(format: value >= 0 ? "+%.1f s" : "%.1f s", value)
    }
}
