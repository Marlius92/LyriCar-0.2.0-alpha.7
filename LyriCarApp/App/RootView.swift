import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.connectionState {
            case .unconfigured, .disconnected, .connecting:
                SpotifyOnboardingView(model: model)
            case .connected, .demo:
                LyriCarLyricsView(model: model)
            }
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView(model: model)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.setAppActive(newPhase == .active)
        }
    }
}
