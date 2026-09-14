import Foundation
#if canImport(Security)
import Security
#endif

/// Reads the entitlements that are actually present after the IPA has been
/// re-signed. Third-party signers may rewrite App Group and Keychain access
/// group identifiers, so runtime code must not assume the identifiers compiled
/// into the unsigned IPA survived unchanged.
public enum LyriCarSigningEntitlements {
    public static let legacyAppGroupIdentifier = "group.a4799f2e729d57e0.1"
    public static let legacyKeychainAccessGroup = "6P85QCBUU6.lyricar.shared"

    public static var applicationIdentifier: String? {
        stringEntitlement("application-identifier")
    }

    public static var developerTeamIdentifier: String? {
        stringEntitlement("com.apple.developer.team-identifier")
    }

    public static var appGroupIdentifiers: [String] {
        stringArrayEntitlement("com.apple.security.application-groups")
    }

    public static var keychainAccessGroups: [String] {
        stringArrayEntitlement("keychain-access-groups")
    }

    public static var resolvedAppGroupIdentifier: String? {
        let groups = appGroupIdentifiers
        if groups.contains(legacyAppGroupIdentifier) {
            return legacyAppGroupIdentifier
        }
        if let preferred = groups.first(where: isLyriCarLikeGroup) {
            return preferred
        }
        return groups.count == 1 ? groups[0] : nil
    }

    public static var resolvedKeychainAccessGroup: String? {
        let groups = keychainAccessGroups
        if groups.contains(legacyKeychainAccessGroup) {
            return legacyKeychainAccessGroup
        }

        // Exclude the private/default application identifier when possible: it
        // is app-specific and therefore cannot be the bridge to another target.
        let applicationID = applicationIdentifier
        let candidates = groups.filter { $0 != applicationID }
        if let preferred = candidates.first(where: isLyriCarLikeGroup) {
            return preferred
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    private static func isLyriCarLikeGroup(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("lyricar")
            || lower.contains("lyricomp")
            || lower.contains("shared")
            || lower.contains("a4799f2e729d57e0.1")
    }

    private static func stringEntitlement(_ name: String) -> String? {
        #if canImport(Security) && os(iOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, name as CFString, nil)
        else { return nil }
        return value as? String
        #else
        return nil
        #endif
    }

    private static func stringArrayEntitlement(_ name: String) -> [String] {
        #if canImport(Security) && os(iOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, name as CFString, nil)
        else { return [] }
        return value as? [String] ?? []
        #else
        return []
        #endif
    }
}
