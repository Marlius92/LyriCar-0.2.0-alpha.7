import Foundation
#if canImport(Security)
import Security
#endif

public struct LyriCarSharedDiagnostics: Sendable, Hashable {
    public let appGroupAvailable: Bool
    public let keychainAccessAvailable: Bool
    public let sharedStateAvailable: Bool

    public init(
        appGroupAvailable: Bool,
        keychainAccessAvailable: Bool,
        sharedStateAvailable: Bool
    ) {
        self.appGroupAvailable = appGroupAvailable
        self.keychainAccessAvailable = keychainAccessAvailable
        self.sharedStateAvailable = sharedStateAvailable
    }
}

public extension LyriCarWidgetSharedStore {
    static func diagnostics() -> LyriCarSharedDiagnostics {
        LyriCarSharedDiagnostics(
            appGroupAvailable: appGroupAvailable,
            keychainAccessAvailable: keychainAccessIsUsable,
            sharedStateAvailable: load() != nil
        )
    }

    private static var keychainAccessIsUsable: Bool {
        #if canImport(Security) && os(iOS)
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
