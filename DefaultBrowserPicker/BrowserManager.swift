import Cocoa
import CoreServices

struct Browser: Hashable {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage
    let isKnown: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: Browser, rhs: Browser) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

final class BrowserManager {
    // Known mainstream browser bundle IDs for smart ordering (lowercased for matching)
    private static let knownBrowserBundleIDs: Set<String> = [
        "com.apple.safari",
        "com.google.chrome",
        "org.mozilla.firefox",
        "company.thebrowser.browser",      // Arc
        "com.brave.browser",
        "com.microsoft.edgemac",
        "com.operasoftware.opera",
        "com.vivaldi.vivaldi",
        "com.kagi.kagimacOS",              // Orion
        "app.zen-browser.zen",             // Zen
    ]

    private let httpsURL = URL(string: "https://example.com")!

    /// Detects all browsers registered as HTTP URL handlers on macOS.
    func detectBrowsers() -> [Browser] {
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: httpsURL)

        var browsers: [Browser] = []
        var seen = Set<String>()

        for appURL in appURLs {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier else {
                continue
            }

            // Deduplicate by bundle ID
            let normalizedID = bundleID.lowercased()
            guard !seen.contains(normalizedID) else { continue }
            seen.insert(normalizedID)

            let name = FileManager.default.displayName(atPath: appURL.path)
                .replacingOccurrences(of: ".app", with: "")

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 16, height: 16)

            let isKnown = Self.knownBrowserBundleIDs.contains(normalizedID)

            browsers.append(Browser(
                bundleIdentifier: bundleID,
                name: name,
                icon: icon,
                isKnown: isKnown
            ))
        }

        // Sort: known browsers first (alphabetical), then others (alphabetical)
        let known = browsers.filter(\.isKnown).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let unknown = browsers.filter { !$0.isKnown }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return known + unknown
    }

    /// Returns the bundle identifier of the current default HTTPS browser.
    func currentDefaultBrowser() -> String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: httpsURL) else {
            return nil
        }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    /// Sets the default browser for HTTP and HTTPS URL schemes.
    func setDefaultBrowser(bundleIdentifier: String) {
        // Use the modern approach: open a URL with the specified app, which triggers
        // the system confirmation dialog for default browser changes.
        // On macOS 12+, calling LSSetDefaultHandlerForURLScheme triggers the OS dialog.
        // We use the CoreServices API as NSWorkspace doesn't have a direct setter.
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleIdentifier as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleIdentifier as CFString)
    }

    /// Returns the icon for the current default browser, or a fallback globe icon.
    func currentDefaultBrowserIcon() -> NSImage {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: httpsURL) else {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "Default Browser")
                ?? NSImage()
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }

    /// Checks if any browsers in the list are not in the known set.
    func hasUnknownBrowsers(in browsers: [Browser]) -> Bool {
        browsers.contains { !$0.isKnown }
    }
}
