import Cocoa

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let browserManager = BrowserManager()
    private let loginItemManager = LoginItemManager()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu()
        super.init()

        menu.delegate = self
        statusItem.menu = menu

        updateMenuBarIcon()
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
        updateMenuBarIcon()
    }

    // MARK: - Menu Construction

    private func rebuildMenu() {
        menu.removeAllItems()

        let browsers = browserManager.detectBrowsers()
        let currentDefault = browserManager.currentDefaultBrowser()

        let hasUnknown = browserManager.hasUnknownBrowsers(in: browsers)
        var addedSeparatorForUnknown = false

        for browser in browsers {
            // Add separator before unknown browsers section
            if hasUnknown && !browser.isKnown && !addedSeparatorForUnknown {
                menu.addItem(.separator())
                addedSeparatorForUnknown = true
            }

            let item = NSMenuItem(
                title: browser.name,
                action: #selector(browserSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.image = browser.icon
            item.representedObject = browser.bundleIdentifier

            if browser.bundleIdentifier.lowercased() == currentDefault?.lowercased() {
                item.state = .on
            }

            menu.addItem(item)
        }

        // Subtitle explaining what "default browser" means
        menu.addItem(.separator())
        let subtitleItem = NSMenuItem(
            title: "Your default browser opens links from other apps",
            action: nil,
            keyEquivalent: ""
        )
        subtitleItem.isEnabled = false
        if let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular) as NSFont? {
            subtitleItem.attributedTitle = NSAttributedString(
                string: subtitleItem.title,
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        }
        menu.addItem(subtitleItem)

        // Start on Login toggle
        menu.addItem(.separator())
        let loginItem = NSMenuItem(
            title: "Start on Login",
            action: #selector(toggleLoginItem(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = loginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func browserSelected(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        browserManager.setDefaultBrowser(bundleIdentifier: bundleID)

        // Update menubar icon after switch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateMenuBarIcon()
        }
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        loginItemManager.toggle()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Menubar Icon

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        button.image = browserManager.currentDefaultBrowserIcon()
        button.image?.isTemplate = false  // Show actual browser icon colors
    }
}
