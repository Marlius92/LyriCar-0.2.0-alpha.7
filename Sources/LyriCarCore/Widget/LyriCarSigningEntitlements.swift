import Foundation

/// Reads the entitlements authorized by the provisioning profile that is
/// actually embedded after the IPA has been signed. Third-party signers may
/// rewrite App Group and Keychain access group identifiers, so runtime code
/// must not assume the identifiers compiled into the unsigned IPA survived
/// unchanged.
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

    /// Picks the same usable App Group in every LyriCar/LyriComp process.
    ///
    /// Signulous can replace our original group with a pool of generated groups
    /// (for example `group.<signer>.1 ... .5`). The order in the provisioning
    /// profile is not guaranteed, therefore all candidates are sorted before a
    /// selection is made. On iOS we additionally probe the container so a group
    /// is never reported as selected unless the current signed executable can
    /// actually open it.
    public static var resolvedAppGroupIdentifier: String? {
        let groups = Array(Set(appGroupIdentifiers)).sorted()

        let orderedCandidates: [String]
        if groups.contains(legacyAppGroupIdentifier) {
            orderedCandidates = [legacyAppGroupIdentifier]
                + groups.filter { $0 != legacyAppGroupIdentifier }
        } else {
            let preferred = groups.filter(isLyriCarLikeGroup)
            let remaining = groups.filter { !preferred.contains($0) }
            orderedCandidates = preferred + remaining
        }

        #if os(iOS)
        return orderedCandidates.first { identifier in
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: identifier
            ) != nil
        }
        #else
        // Unit tests and non-iOS builds cannot probe App Group containers.
        return orderedCandidates.first
        #endif
    }

    public static var resolvedKeychainAccessGroup: String? {
        let groups = keychainAccessGroups
        if groups.contains(legacyKeychainAccessGroup) {
            return legacyKeychainAccessGroup
        }

        // Wildcard entries authorize signing but are not literal access-group
        // values that can be passed to SecItem APIs at runtime. Apple-private
        // groups such as com.apple.token must never be used for LyriCar state.
        let applicationID = applicationIdentifier
        let candidates = groups
            .filter {
                $0 != applicationID
                    && !$0.contains("*")
                    && !$0.hasPrefix("com.apple.")
            }
            .sorted()

        if let preferred = candidates.first(where: isLyriCarLikeGroup) {
            return preferred
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    /// True when a signed-device provisioning profile could be decoded. The
    /// simulator and unsigned build products normally return false here.
    public static var provisioningProfileAvailable: Bool {
        profileEntitlements != nil
    }

    private static func isLyriCarLikeGroup(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("lyricar")
            || lower.contains("lyricomp")
            || lower.contains("shared")
            || lower.contains("a4799f2e729d57e0.1")
    }

    private static func stringEntitlement(_ name: String) -> String? {
        profileEntitlements?[name] as? String
    }

    private static func stringArrayEntitlement(_ name: String) -> [String] {
        profileEntitlements?[name] as? [String] ?? []
    }

    /// `embedded.mobileprovision` is a CMS container whose payload contains an
    /// XML plist. Extracting that plist avoids private/unavailable SecTask APIs
    /// and, importantly for Signulous, inspects the profile shipped with the
    /// re-signed application rather than our original unsigned entitlements.
    private static let profileEntitlements: [String: Any]? = {
        #if os(iOS)
        guard let profileURL = Bundle.main.url(
            forResource: "embedded",
            withExtension: "mobileprovision"
        ), let profileData = try? Data(contentsOf: profileURL) else {
            return nil
        }

        // The XML payload is ASCII/UTF-8 even though the surrounding CMS data
        // is binary. Lossy UTF-8 decoding preserves the XML delimiters/content.
        let decoded = String(decoding: profileData, as: UTF8.self)
        guard let xmlStart = decoded.range(of: "<?xml"),
              let plistEnd = decoded.range(
                of: "</plist>",
                range: xmlStart.lowerBound..<decoded.endIndex
              ) else {
            return nil
        }

        let plistText = String(decoded[xmlStart.lowerBound..<plistEnd.upperBound])
        guard let plistData = plistText.data(using: .utf8),
              let object = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
              ),
              let profile = object as? [String: Any],
              let entitlements = profile["Entitlements"] as? [String: Any] else {
            return nil
        }
        return entitlements
        #else
        return nil
        #endif
    }()
}
