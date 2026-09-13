import Combine
import Foundation
import LyriCarCore
import UIKit

@MainActor
final class AppModel: ObservableObject {
    enum ConnectionState: Equatable {
        case unconfigured
        case disconnected
        case connecting
        case connected
        case demo
    }

    enum LyricsState: Equatable {
        case idle
        case loading
        case available
        case instrumental
        case unavailable
        case failed(String)
    }

    @Published private(set) var connectionState: ConnectionState
    @Published private(set) var playback: PlaybackSnapshot?
    @Published private(set) var lyrics: LyricsDocument?
    @Published private(set) var lyricsState: LyricsState = .idle
    @Published private(set) var statusMessage = ""
    @Published var showSettings = false
    @Published private(set) var carPlayConnected = false
    @Published private(set) var appIsActive = true

    let settings: LyriCarSettings
    let driveMode: DriveModeManager
    let spotifyConfiguration: SpotifyConfigurationStore

    private let tokenStore: KeychainTokenStore
    private let auth: SpotifyAuthController
    private let spotify: SpotifyWebAPI
    private let lyricsRepository: LyricsRepository
    private let liveActivity = LyriCarActivityManager()
    private let widgetState = LyriCarWidgetStateManager()
    private var playbackClock = PlaybackClock()
    private var pollTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var activityTask: Task<Void, Never>?
    private var demoTask: Task<Void, Never>?
    private var started = false

    var isDemoMode: Bool { connectionState == .demo }
    var isSpotifyConfigured: Bool { spotifyConfiguration.isConfigured }

    init() {
        let settings = LyriCarSettings()
        let driveMode = DriveModeManager()
        let configurationStore = SpotifyConfigurationStore()
        let tokenStore = KeychainTokenStore()
        let auth = SpotifyAuthController(
            configurationProvider: { configurationStore.configuration },
            tokenStore: tokenStore
        )

        self.settings = settings
        self.driveMode = driveMode
        self.spotifyConfiguration = configurationStore
        self.tokenStore = tokenStore
        self.auth = auth
        self.spotify = SpotifyWebAPI(auth: auth)
        self.lyricsRepository = Self.makeLyricsRepository()

        if !configurationStore.isConfigured {
            connectionState = .unconfigured
        } else if auth.hasStoredToken {
            connectionState = .connected
        } else {
            connectionState = .disconnected
        }
    }

    deinit {
        pollTask?.cancel()
        lyricsTask?.cancel()
        activityTask?.cancel()
        demoTask?.cancel()
    }

    func start() {
        guard !started else { return }
        started = true
        driveMode.setEnabled(settings.driveModeEnabled)
        if connectionState == .connected { startPolling() }
        startActivityTicker()
    }

    func setAppActive(_ active: Bool) {
        appIsActive = active
        if active, connectionState == .connected {
            startPolling()
            refreshNow()
        }
    }

    func configureAndConnectSpotify(clientID: String) async {
        stopDemo(resetState: false)
        do {
            try? auth.disconnect()
            try spotifyConfiguration.save(clientID: clientID)
            connectionState = .disconnected
            statusMessage = "Client ID salvato. Apertura di Spotify…"
            await connectSpotify()
        } catch {
            connectionState = spotifyConfiguration.isConfigured ? .disconnected : .unconfigured
            statusMessage = error.localizedDescription
        }
    }

    func connectSpotify() async {
        stopDemo(resetState: false)
        guard spotifyConfiguration.isConfigured else {
            connectionState = .unconfigured
            statusMessage = SpotifyConfigurationError.missingClientID.localizedDescription
            return
        }

        connectionState = .connecting
        statusMessage = "Collegamento a Spotify…"
        do {
            _ = try await auth.authenticate()
            connectionState = .connected
            statusMessage = "Spotify collegata. Avvia un brano nell’app Spotify."
            startPolling()
            await refreshPlayback(after: 0)
        } catch {
            connectionState = .disconnected
            statusMessage = error.localizedDescription
        }
    }

    func disconnectSpotify(clearClientID: Bool = false) async {
        stopDemo(resetState: false)
        do { try auth.disconnect() } catch { statusMessage = error.localizedDescription }
        cancelPlaybackWork()
        resetPlaybackPresentation()
        if clearClientID { spotifyConfiguration.clear() }
        connectionState = spotifyConfiguration.isConfigured ? .disconnected : .unconfigured
        await liveActivity.end()
    }

    func startDemo() {
        cancelPlaybackWork()
        playbackClock.reset()
        connectionState = .demo
        playback = LyriCarDemo.snapshot()
        lyrics = LyriCarDemo.lyrics
        lyricsState = .available
        statusMessage = "Modalità demo: timeline simulata, nessun audio riprodotto."
        startDemoTicker()
    }

    func stopDemo() {
        stopDemo(resetState: true)
    }

    func togglePlayPause() {
        guard let playback else { return }
        if isDemoMode {
            let position = playback.estimatedPosition()
            self.playback = LyriCarDemo.snapshot(
                position: position,
                isPlaying: !playback.isPlaying
            )
            return
        }

        Task {
            do {
                if playback.isPlaying {
                    try await spotify.pause(deviceID: playback.deviceID)
                } else {
                    try await spotify.play(deviceID: playback.deviceID)
                }
                await refreshPlayback(after: 0.35)
            } catch { statusMessage = error.localizedDescription }
        }
    }

    func previousTrack() {
        if isDemoMode {
            playback = LyriCarDemo.snapshot(position: 0, isPlaying: playback?.isPlaying ?? true)
            return
        }
        Task {
            do {
                try await spotify.previous(deviceID: playback?.deviceID)
                await refreshPlayback(after: 0.45)
            } catch { statusMessage = error.localizedDescription }
        }
    }

    func nextTrack() {
        if isDemoMode {
            playback = LyriCarDemo.snapshot(position: 0, isPlaying: playback?.isPlaying ?? true)
            return
        }
        Task {
            do {
                try await spotify.next(deviceID: playback?.deviceID)
                await refreshPlayback(after: 0.45)
            } catch { statusMessage = error.localizedDescription }
        }
    }

    func refreshNow() {
        guard connectionState == .connected else { return }
        Task { await refreshPlayback(after: 0) }
    }

    func setDriveMode(_ enabled: Bool) {
        settings.driveModeEnabled = enabled
        driveMode.setEnabled(enabled)
    }

    func setLiveActivity(_ enabled: Bool) {
        settings.liveActivityEnabled = enabled
        if !enabled { Task { await liveActivity.end() } }
    }

    func clearLyricsCache() async {
        do {
            try await lyricsRepository.clearCache()
            statusMessage = "Cache dei testi eliminata."
            if let playback, !isDemoMode {
                loadLyrics(for: playback.track, forceRefresh: true)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func setCarPlayConnected(_ connected: Bool) {
        carPlayConnected = connected
        if connected {
            start()
            if connectionState == .connected {
                startPolling()
                refreshNow()
            }
        }
    }

    func openSpotify() {
        let nativeURL = URL(string: "spotify://")!
        let webURL = URL(string: "https://open.spotify.com")!
        UIApplication.shared.open(nativeURL, options: [:]) { opened in
            if !opened { UIApplication.shared.open(webURL) }
        }
    }

    func openSpotifyDashboard() {
        guard let url = URL(string: "https://developer.spotify.com/dashboard") else { return }
        UIApplication.shared.open(url)
    }

    func frame(at date: Date = Date()) -> LyricFrame {
        guard let playback else { return .empty }
        return LyricsSyncEngine(transitionWindow: settings.transitionWindow).frame(
            for: lyrics,
            playbackPosition: playback.estimatedPosition(at: date),
            userOffset: settings.lyricsOffset
        )
    }

    private func startPolling() {
        guard pollTask == nil || pollTask?.isCancelled == true else { return }
        pollTask = Task { [weak self] in
            defer { self?.pollTask = nil }
            while !Task.isCancelled {
                guard let self, self.connectionState == .connected else { return }
                await self.refreshPlayback(after: 0)
                let interval: TimeInterval
                if self.carPlayConnected {
                    interval = 1.5
                } else if self.appIsActive {
                    interval = 2.0
                } else if self.settings.driveModeEnabled {
                    interval = 3.0
                } else {
                    interval = 5.0
                }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func startActivityTicker() {
        activityTask?.cancel()
        activityTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let playback = self.playback {
                    let frame = self.frame()
                    await self.liveActivity.update(
                        playback: playback,
                        frame: frame,
                        enabled: self.settings.liveActivityEnabled
                    )
                    self.widgetState.update(playback: playback, frame: frame)
                } else {
                    await self.liveActivity.end()
                    self.widgetState.clear()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func startDemoTicker() {
        demoTask?.cancel()
        demoTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.connectionState == .demo else { return }
                if let playback = self.playback,
                   playback.isPlaying,
                   playback.estimatedPosition() >= max(0, playback.track.duration - 0.05) {
                    self.playback = LyriCarDemo.snapshot(position: 0, isPlaying: true)
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopDemo(resetState: Bool) {
        guard connectionState == .demo || demoTask != nil else { return }
        demoTask?.cancel()
        demoTask = nil
        resetPlaybackPresentation()
        if resetState {
            if !spotifyConfiguration.isConfigured {
                connectionState = .unconfigured
            } else if auth.hasStoredToken {
                connectionState = .connected
                startPolling()
            } else {
                connectionState = .disconnected
            }
            statusMessage = ""
        }
    }

    private func refreshPlayback(after delay: TimeInterval) async {
        if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
        guard connectionState == .connected else { return }
        do {
            let incoming = try await spotify.currentPlayback()
            apply(incoming)
            statusMessage = incoming == nil ? "Apri Spotify e avvia un brano." : ""
        } catch SpotifyAuthError.notAuthenticated {
            connectionState = .disconnected
            statusMessage = SpotifyAuthError.notAuthenticated.localizedDescription
            playbackClock.reset()
            playback = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func apply(_ incoming: PlaybackSnapshot?) {
        let oldKey = playback?.track.stableCacheKey
        playback = playbackClock.apply(incoming)
        guard let incoming = playback else {
            lyricsTask?.cancel()
            lyrics = nil
            lyricsState = .idle
            return
        }
        if oldKey != incoming.track.stableCacheKey || lyrics == nil {
            loadLyrics(for: incoming.track)
        }
    }

    private func loadLyrics(for track: TrackIdentity, forceRefresh: Bool = false) {
        lyricsTask?.cancel()
        lyrics = nil
        lyricsState = .loading
        lyricsTask = Task { [weak self] in
            guard let self else { return }
            do {
                let document = try await self.lyricsRepository.lyrics(for: track, forceRefresh: forceRefresh)
                guard !Task.isCancelled,
                      self.playback?.track.stableCacheKey == track.stableCacheKey else { return }
                self.lyrics = document
                if let document {
                    self.lyricsState = document.instrumental ? .instrumental : .available
                } else {
                    self.lyricsState = .unavailable
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.lyricsState = .failed(error.localizedDescription)
            }
        }
    }

    private func cancelPlaybackWork() {
        pollTask?.cancel()
        pollTask = nil
        lyricsTask?.cancel()
        lyricsTask = nil
        demoTask?.cancel()
        demoTask = nil
    }

    private func resetPlaybackPresentation() {
        playbackClock.reset()
        playback = nil
        lyrics = nil
        lyricsState = .idle
    }

    private static func makeLyricsRepository() -> LyricsRepository {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("LyriCar/Lyrics", isDirectory: true)
        do {
            let cache = try LyricsCache(directory: directory)
            return LyricsRepository(provider: LRCLIBClient(), cache: cache)
        } catch {
            let fallback = FileManager.default.temporaryDirectory
                .appendingPathComponent("LyriCar-Lyrics", isDirectory: true)
            let cache = try! LyricsCache(directory: fallback)
            return LyricsRepository(provider: LRCLIBClient(), cache: cache)
        }
    }
}

@MainActor
final class LyriCarEnvironment {
    static let shared = LyriCarEnvironment()
    let model = AppModel()
    private init() {}
}
