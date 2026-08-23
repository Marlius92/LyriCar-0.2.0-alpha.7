import Foundation
import LyriCarCore

/// Original, royalty-free text used to validate the complete renderer on iPhone
/// before Spotify is configured. No audio is played: the timeline is simulated.
enum LyriCarDemo {
    static let duration: TimeInterval = 48

    static let track = TrackIdentity(
        id: "lyricar-demo",
        title: "Prima corsa",
        artists: ["LyriCar Demo"],
        album: "Display Test 9,3\"",
        duration: duration
    )

    static let lyrics = LyricsDocument(
        provider: .local,
        trackTitle: track.title,
        artistName: track.displayArtist,
        albumName: track.album,
        duration: duration,
        lines: [
            LyricLine(index: 0, timestamp: 0.8, text: "La strada si accende davanti a noi"),
            LyricLine(index: 1, timestamp: 5.0, text: "Il ritmo segue ogni curva"),
            LyricLine(index: 2, timestamp: 9.2, text: "Una riga emerge dal silenzio"),
            LyricLine(index: 3, timestamp: 13.4, text: "Grande, chiara, al centro dello sguardo"),
            LyricLine(index: 4, timestamp: 17.8, text: "Le parole passate si allontanano"),
            LyricLine(index: 5, timestamp: 22.0, text: "Quelle future si avvicinano piano"),
            LyricLine(index: 6, timestamp: 26.4, text: "La transizione rimane continua"),
            LyricLine(index: 7, timestamp: 30.6, text: "Il tempo scorre senza tornare indietro"),
            LyricLine(index: 8, timestamp: 35.0, text: "LyriCar accompagna la canzone"),
            LyricLine(index: 9, timestamp: 39.4, text: "Spotify continua a guidare la musica"),
            LyricLine(index: 10, timestamp: 43.6, text: "E il testo riparte dall’inizio")
        ],
        plainLyrics: nil,
        instrumental: false
    )

    static func snapshot(
        position: TimeInterval = 0,
        isPlaying: Bool = true,
        capturedAt: Date = Date()
    ) -> PlaybackSnapshot {
        PlaybackSnapshot(
            track: track,
            position: position,
            isPlaying: isPlaying,
            capturedAt: capturedAt,
            deviceID: nil
        )
    }
}
