import UIKit

/// UIKit bridge retained for the SwiftUI app lifecycle.
/// The experimental CarPlay scene is declared only in Info-CarPlay.plist, so the
/// standard target never needs to manufacture or request a CarPlay scene.
final class AppDelegate: NSObject, UIApplicationDelegate {}
