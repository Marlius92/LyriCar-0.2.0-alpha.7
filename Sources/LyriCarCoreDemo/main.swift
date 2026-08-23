import Foundation
import LyriCarCore

let sample = """
[ar:LyriCar]
[ti:Renderer demonstration]
[00:00.00]The road begins beneath the dashboard glow
[00:04.00]A quiet line prepares to rise
[00:08.00]The current words become the clearest
[00:12.00]Then drift away on either side
[00:16.00]LyriCar keeps the timing close
[00:20.00]And leaves the music inside Spotify
"""

do {
    let parsed = try LRCParser().parse(sample)
    let document = LyricsDocument(
        provider: .local,
        trackTitle: "Renderer demonstration",
        artistName: "LyriCar",
        duration: 24,
        lines: parsed.lines
    )
    let engine = LyricsSyncEngine()
    for second in stride(from: 0.0, through: 22.0, by: 2.0) {
        let frame = engine.frame(for: document, playbackPosition: second)
        print(String(format: "%5.1f  %@", second, frame.current?.text ?? "—"))
    }
} catch {
    fputs("LyriCar core demo failed: \(error)\n", stderr)
    exit(1)
}
