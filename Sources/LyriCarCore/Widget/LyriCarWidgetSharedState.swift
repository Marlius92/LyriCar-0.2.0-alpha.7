import Foundation
#if canImport(Security)
import Security
#endif

/// Snapshot shared between the iPhone app and the WidgetKit extension.
/// The widget intentionally receives only presentation data; Spotify credentials
/// and the complete lyrics document never leave the app container.
public struct LyriCarWidgetSharedState: Codable, Hashable, Sendable {
    public var title: String
    public var artist: String
    public var previous2: String
    public var previous1: String
    public var current: String
    public var next1: String
    public var next2: String
    public var position: TimeInterval
    public var duration: TimeInterval
    public var isPlaying: Bool
    public var capturedAt: Date
    public var currentLineStartedAt: TimeInterval?
    public var nextLineStartsAt: TimeInterval?
    public var karaokeEligible: Bool

    public init(
        title: String,
        artist: String,
        previous2: String,
        previous1: String,
        current: String,
        next1: String,
        next2: String,
        position: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        capturedAt: Date,
        currentLineStartedAt: TimeInterval?,
        nextLineStartsAt: TimeInterval?,
        karaokeEligible: Bool
    ) {
        self.title = title
        self.artist = artist
        self.previous2 = previous2
        self.previous1 = previous1
        self.current = current
        self.next1 = next1
        self.next2 = next2
        self.position = max(0, position)
        self.duration = max(0, duration)
        self.isPlaying = isPlaying
        self.capturedAt = capturedAt
        self.currentLineStartedAt = currentLineStartedAt
        self.nextLineStartsAt = nextLineStartsAt
        self.karaokeEligible = karaokeEligible
    }

    public func estimatedPosition(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return min(max(position, 0), duration) }
        return min(max(position + max(0, date.timeIntervalSince(capturedAt)), 0), duration)
    }

    public var playbackInterval: ClosedRange<Date> {
        let safeDuration = max(duration, 0.001)
        let safePosition = min(max(position, 0), safeDuration)
        let start = capturedAt.addingTimeInterval(-safePosition)
        return start...start.addingTimeInterval(safeDuration)
    }

    public var remainingInterval: ClosedRange<Date> {
        let estimated = estimatedPosition()
        let now = Date()
        return now...now.addingTimeInterval(max(0.001, duration - estimated))
    }

    public static let placeholder = LyriCarWidgetSharedState(
        title: "LyriCar",
        artist: "Apri LyriCar e avvia Spotify",
        previous2: "",
        previous1: "",
        current: "Testi sincronizzati",
        next1: "in attesa del brano…",
        next2: "",
        position: 0,
        duration: 1,
        isPlaying: false,
        capturedAt: Date(),
        currentLineStartedAt: nil,
        nextLineStartsAt: nil,
        karaokeEligible: false
    )
}

public enum LyriCarWidgetSharedTransport: String, Codable, Hashable, Sendable {
    case appGroupAndKeychain
    case appGroup
    case keychain
    case unavailable

    public var displayName: String {
        switch self {
        case .appGroupAndKeychain: return "App Group + Keychain"
        case .appGroup: return "App Group"
        case .keychain: return "Keychain"
        case .unavailable: return "Non disponibile"
        }
    }
}

/// Redundant shared store used by both the host app and the widget extension.
///
/// Signulous can re-sign nested extensions differently from the host app. To make
/// device testing resilient, LyriCar writes the same compact snapshot through two
/// independent channels that are both permitted by the current provisioning
/// profile: App Group storage and a shared Keychain access group.
public enum LyriCarWidgetSharedStore {
    public static let stateKey = "lyricar.widget.shared-state.v2"
    public static let appGroupIdentifier = "group.a4799f2e729d57e0.1"
    public static let keychainAccessGroup = "6P85QCBUU6.lyricar.shared"

    private static let sharedFilename = "LyriCarWidgetState-v2.json"
    private static let keychainService = "com.marlius.lyricar.widget-state"
    private static let keychainAccount = "current"

    @discardableResult
    public static func save(_ state: LyriCarWidgetSharedState) -> LyriCarWidgetSharedTransport {
        guard let data = try? JSONEncoder().encode(state) else { return .unavailable }

        let appGroupOK = saveToAppGroup(data)
        let keychainOK = saveToKeychain(data)

        switch (appGroupOK, keychainOK) {
        case (true, true): return .appGroupAndKeychain
        case (true, false): return .appGroup
        case (false, true): return .keychain
        case (false, false): return .unavailable
        }
    }

    public static func load() -> LyriCarWidgetSharedState? {
        if let data = loadFromAppGroup(),
           let state = try? JSONDecoder().decode(LyriCarWidgetSharedState.self, from: data) {
            return state
        }
        if let data = loadFromKeychain(),
           let state = try? JSONDecoder().decode(LyriCarWidgetSharedState.self, from: data) {
            return state
        }
        return nil
    }

    @discardableResult
    public static func clear() -> LyriCarWidgetSharedTransport {
        let appGroupOK = clearAppGroup()
        let keychainOK = clearKeychain()
        switch (appGroupOK, keychainOK) {
        case (true, true): return .appGroupAndKeychain
        case (true, false): return .appGroup
        case (false, true): return .keychain
        case (false, false): return .unavailable
        }
    }

    public static var appGroupAvailable: Bool {
        sharedContainerURL != nil
    }

    private static var sharedContainerURL: URL? {
        #if os(iOS)
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        #else
        nil
        #endif
    }

    private static var sharedFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(sharedFilename, isDirectory: false)
    }

    private static func saveToAppGroup(_ data: Data) -> Bool {
        var wrote = false

        if let url = sharedFileURL {
            do {
                try data.write(to: url, options: [.atomic])
                wrote = true
            } catch {
                // Keep the UserDefaults attempt below as a second App Group path.
            }
        }

        #if os(iOS)
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            defaults.set(data, forKey: stateKey)
            defaults.synchronize()
            wrote = true
        }
        #endif

        return wrote
    }

    private static func loadFromAppGroup() -> Data? {
        if let url = sharedFileURL,
           let data = try? Data(contentsOf: url) {
            return data
        }

        #if os(iOS)
        return UserDefaults(suiteName: appGroupIdentifier)?.data(forKey: stateKey)
        #else
        return nil
        #endif
    }

    private static func clearAppGroup() -> Bool {
        var cleared = false
        if let url = sharedFileURL {
            try? FileManager.default.removeItem(at: url)
            cleared = true
        }
        #if os(iOS)
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            defaults.removeObject(forKey: stateKey)
            defaults.synchronize()
            cleared = true
        }
        #endif
        return cleared
    }

    private static func saveToKeychain(_ data: Data) -> Bool {
        #if canImport(Security) && os(iOS)
        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecAttrAccessGroup: keychainAccessGroup
        ]

        let updateStatus = SecItemUpdate(
            base as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var add = base
        add[kSecValueData] = data
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        #else
        return false
        #endif
    }

    private static func loadFromKeychain() -> Data? {
        #if canImport(Security) && os(iOS)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecAttrAccessGroup: keychainAccessGroup,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
        #else
        return nil
        #endif
    }

    private static func clearKeychain() -> Bool {
        #if canImport(Security) && os(iOS)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecAttrAccessGroup: keychainAccessGroup
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
        #else
        return false
        #endif
    }
}
