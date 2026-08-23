import SwiftUI

@main
struct LyriCarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = LyriCarEnvironment.shared.model

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .task { model.start() }
        }
    }
}
