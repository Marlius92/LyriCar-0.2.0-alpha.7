import CarPlay
import SwiftUI
import UIKit

/// Experimental navigation-scene renderer.
/// It compiles with the app, but iOS only launches it when the signed profile contains
/// Apple's navigation CarPlay entitlement. The standard build intentionally does not
/// claim an ungranted entitlement.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private weak var carWindow: CPWindow?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window

        let mapTemplate = CPMapTemplate()
        interfaceController.setRootTemplate(mapTemplate, animated: false, completion: nil)

        let model = LyriCarEnvironment.shared.model
        let controller = UIHostingController(
            rootView: LyriCarLyricsView(model: model, showsSettingsButton: false)
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
        )
        controller.view.backgroundColor = .black
        window.rootViewController = controller
        window.isHidden = false
        model.setCarPlayConnected(true)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        LyriCarEnvironment.shared.model.setCarPlayConnected(false)
        self.interfaceController = nil
        self.carWindow = nil
    }
}
