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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
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

                Text("Non collegare Spotify anche qui: la Companion usa lo stato condiviso di LyriCar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
        .task {
            while !Task.isCancelled {
                state = LyriCarWidgetSharedStore.load()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
