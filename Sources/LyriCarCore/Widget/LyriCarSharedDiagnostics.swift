import Foundation
#if canImport(Security)
import Security
#endif

public struct LyriCarSharedDiagnostics: Sendable, Hashable {
    public let appGroupAvailable: Bool
    public let keychainAccessAvailable: Bool
    public let sharedStateAvailable: Bool
    public let effectiveAppGroup: String?
    public let effectiveKeychainGroup: String?
    public let signedAppGroups: [String]
    public let signedKeychainGroups: [String]
    public let applicationIdentifier: String?
    public let teamIdentifier: String?

    public init(
        appGroupAvailable: Bool,
        keychainAccessAvailable: Bool,
        sharedStateAvailable: Bool,
        effectiveAppGroup: String?,
        effectiveKeychainGroup: String?,
        signedAppGroups: [String],
        signedKeychainGroups: [String],
        applicationIdentifier: String?,
        teamIdentifier: String?
    ) {
        self.appGroupAvailable = appGroupAvailable
        self.keychainAccessAvailable = keychainAccessAvailable
        self.sharedStateAvailable = sharedStateAvailable
        self.effectiveAppGroup = effectiveAppGroup
        self.effectiveKeychainGroup = effectiveKeychainGroup
        self.signedAppGroups = signedAppGroups
        self.signedKeychainGroups = signedKeychainGroups
        self.applicationIdentifier = applicationIdentifier
        self.teamIdentifier = teamIdentifier
    }
}

public extension LyriCarWidgetSharedStore {
    static func diagnostics() -> LyriCarSharedDiagnostics {
        LyriCarSharedDiagnostics(
            appGroupAvailable: appGroupAvailable,
            keychainAccessAvailable: keychainAccessIsUsable,
            sharedStateAvailable: load() != nil,
            effectiveAppGroup: appGroupIdentifier,
            effectiveKeychainGroup: keychainAccessGroup,
            signedAppGroups: LyriCarSigningEntitlements.appGroupIdentifiers,
            signedKeychainGroups: LyriCarSigningEntitlements.keychainAccessGroups,
            applicationIdentifier: LyriCarSigningEntitlements.applicationIdentifier,
            teamIdentifier: LyriCarSigningEntitlements.developerTeamIdentifier
        )
    }

    private static var keychainAccessIsUsable: Bool {
        #if canImport(Security) && os(iOS)
        guard let keychainAccessGroup else { return false }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.marlius.lyricar.widget-state.diagnostics",
            kSecAttrAccount: "entitlement-check",
            kSecAttrAccessGroup: keychainAccessGroup,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecItemNotFound
        #else
        return false
        #endif
    }
}
