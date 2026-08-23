import SwiftUI
import UIKit

struct SpotifyOnboardingView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var spotifyConfiguration: SpotifyConfigurationStore
    @State private var clientID = ""
    @State private var showsClientIDEditor = false
    @FocusState private var clientIDFocused: Bool

    init(model: AppModel) {
        self.model = model
        _spotifyConfiguration = ObservedObject(wrappedValue: model.spotifyConfiguration)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 34)

                    Image(systemName: "text.quote")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(spacing: 8) {
                        Text("LyriCar")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("Testi sincronizzati leggibili sul display dell’auto, mentre Spotify continua a gestire la musica.")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.64))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 600)
                    }

                    featureCard

                    if spotifyConfiguration.isConfigured && !showsClientIDEditor {
                        configuredSpotifyCard
                    } else {
                        clientIDCard
                    }

                    Button {
                        model.startDemo()
                    } label: {
                        Label("Prova subito la demo iPhone", systemImage: "play.rectangle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: 420)
                            .padding(.vertical, 15)
                            .background(Color.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if !model.statusMessage.isEmpty {
                        Text(model.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 560)
                    }

                    Text("Il Client ID identifica l’app nel login Spotify; non è il Client Secret. I comandi Player tramite Web API richiedono Spotify Premium.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.40))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)

                    Spacer(minLength: 34)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            clientID = spotifyConfiguration.clientID
            showsClientIDEditor = !spotifyConfiguration.isConfigured
        }
        .onChange(of: spotifyConfiguration.clientID) { _, value in
            if !clientIDFocused { clientID = value }
        }
    }

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Cinque righe con dissolvenza prospettica", systemImage: "text.aligncenter")
            Label("Barra, tempo trascorso e restante", systemImage: "progress.indicator")
            Label("Precedente, play/pausa e successivo", systemImage: "playpause.fill")
        }
        .font(.headline)
        .foregroundStyle(.white.opacity(0.82))
        .frame(maxWidth: 560, alignment: .leading)
        .padding(22)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }

    private var configuredSpotifyCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spotify configurata")
                        .font(.headline)
                    Text("Client ID: \(spotifyConfiguration.maskedClientID)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            Button {
                Task { await model.connectSpotify() }
            } label: {
                HStack(spacing: 12) {
                    if model.connectionState == .connecting {
                        ProgressView().tint(.black)
                    }
                    Text(model.connectionState == .connecting ? "Collegamento…" : "Collega Spotify")
                        .font(.headline)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(model.connectionState == .connecting)

            HStack(spacing: 18) {
                Button("Apri Spotify") { model.openSpotify() }
                Button("Modifica Client ID") {
                    showsClientIDEditor = true
                    clientIDFocused = true
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: 560)
        .padding(22)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }

    private var clientIDCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Configura Spotify una sola volta")
                .font(.headline)

            Text("Nel dashboard Spotify crea un’app Web API e registra esattamente questa Redirect URI:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))

            HStack(spacing: 10) {
                Text(spotifyConfiguration.redirectURI)
                    .font(.subheadline.monospaced().weight(.semibold))
                    .textSelection(.enabled)
                Spacer()
                Button("Copia") {
                    UIPasteboard.general.string = spotifyConfiguration.redirectURI
                }
                .font(.caption.weight(.semibold))
            }
            .padding(13)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 8) {
                Text("Client ID")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                HStack(spacing: 10) {
                    TextField("Incolla il Client ID Spotify", text: $clientID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .font(.subheadline.monospaced())
                        .focused($clientIDFocused)
                        .submitLabel(.done)
                    Button("Incolla") {
                        if let value = UIPasteboard.general.string { clientID = value }
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(13)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            }

            Button {
                Task { await model.configureAndConnectSpotify(clientID: clientID) }
            } label: {
                HStack(spacing: 12) {
                    if model.connectionState == .connecting {
                        ProgressView().tint(.black)
                    }
                    Text(model.connectionState == .connecting ? "Collegamento…" : "Salva e collega Spotify")
                        .font(.headline)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(model.connectionState == .connecting || clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            HStack(spacing: 18) {
                Button("Apri dashboard Spotify") { model.openSpotifyDashboard() }
                if spotifyConfiguration.isConfigured {
                    Button("Annulla") {
                        clientID = spotifyConfiguration.clientID
                        showsClientIDEditor = false
                        clientIDFocused = false
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(22)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 24))
    }
}
