import Foundation
import UIKit

/// Represents an installed app for the shield picker.
public struct InstalledApp: Identifiable {
    public let id = UUID()
    public let bundleId: String
    public let name: String

    public init(bundleId: String, name: String) {
        self.bundleId = bundleId
        self.name = name
    }
}

/// Manages App shielding (hiding selected apps during focus sessions).
///
/// REQUIRES TrollStore installation with platform-application entitlement.
/// Uses private LSApplicationWorkspace API to hide/unhide apps.
///
/// On non-TrollStore installs, this silently no-ops (graceful degradation).
public final class FocusShieldManager {

    public static let shared = FocusShieldManager()

    private init() {}

    // MARK: - Private framework bridge
    // LSApplicationWorkspace is in MobileCoreServices / FrontBoard private framework.
    // We use NSClassFromString + perform selector to avoid import issues.

    private func applicationWorkspace() -> NSObject? {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else {
            return nil
        }
        // [LSApplicationWorkspace defaultWorkspace]
        let workspace = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue()
        return workspace as? NSObject
    }

    // MARK: - Public API

    /// Activate shielding: hide all apps in the shielded list.
    public func activateShield() {
        guard AppSettings.shared.appShieldEnabled else { return }
        for bundleId in AppSettings.shared.shieldedBundleIds {
            hideApp(bundleId: bundleId)
        }
    }

    /// Deactivate shielding: unhide all previously hidden apps.
    public func deactivateShield() {
        for bundleId in AppSettings.shared.shieldedBundleIds {
            unhideApp(bundleId: bundleId)
        }
    }

    /// List all installed apps (for the settings picker).
    public func listInstalledApps() -> [InstalledApp] {
        guard let workspace = applicationWorkspace() else {
            // Fallback: return empty, UI will show "no apps found"
            return []
        }

        // [LSApplicationWorkspace allInstalledApplications]
        let selector = NSSelectorFromString("allInstalledApplications")
        guard let apps = workspace.perform(selector)?.takeUnretainedValue() as? [NSObject] else {
            return []
        }

        return apps.compactMap { app in
            // LSApplicationProxy has applicationIdentifier and localizedName
            let bundleId = app.value(forKey: "applicationIdentifier") as? String ?? ""
            let name = app.value(forKey:("localizedName")) as? String ??
                       app.value(forKey: "bundleDisplayName") as? String ??
                       bundleId
            return InstalledApp(bundleId: bundleId, name: name)
        }
        .filter { !$0.bundleId.isEmpty && !$0.bundleId.hasPrefix("com.apple.") }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Private helpers

    private func hideApp(bundleId: String) {
        guard let workspace = applicationWorkspace() else { return }
        // [LSApplicationWorkspace uninstallApplication:withOptions:] or
        // use LSApplicationProxy.uninstall — but we DON'T want to delete.
        //
        // Better approach: use setApplicationHidden:forBundleIdentifier:
        let selector = NSSelectorFromString("setApplicationHidden:forBundleIdentifier:")
        if workspace.responds(to: selector) {
            _ = workspace.perform(selector, with: true, with: bundleId)
        }
    }

    private func unhideApp(bundleId: String) {
        guard let workspace = applicationWorkspace() else { return }
        let selector = NSSelectorFromString("setApplicationHidden:forBundleIdentifier:")
        if workspace.responds(to: selector) {
            _ = workspace.perform(selector, with: false, with: bundleId)
        }
    }
}
