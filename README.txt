# LyriCar 0.2.4-alpha.11 — AppIcon packaging fix

- AppIcon/Assets.xcassets are explicitly placed in the Xcode resources build phase using XcodeGen `buildPhase: resources`.
- The approved LyriCar icon is included as a modern universal 1024×1024 iOS app icon.
- Unsigned IPA packaging now aborts if `Assets.car` is missing from the built `.app` bundle.
- The same resource fix applies to both LyriCar and LyriCarExperimental targets.
