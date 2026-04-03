import Cocoa

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let browserManager = BrowserManager()
    private let loginItemManager = LoginItemManager()
    private var lastKnownDefault: String?
    private var eventStream: FSEventStreamRef?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu()
        super.init()

        menu.delegate = self
        statusItem.menu = menu

        lastKnownDefault = browserManager.currentDefaultBrowser()
        updateMenuBarIcon()

        startFSEventStream()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appDidActivate(_ notification: Notification) {
        checkForDefaultBrowserChange(readFromDisk: false)
    }

    // MARK: - FSEventStream

    private func startFSEventStream() {
        let dirPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Preferences/com.apple.LaunchServices")

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
            guard let info = clientCallBackInfo else { return }
            let controller = Unmanaged<StatusBarController>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async {
                controller.checkForDefaultBrowserChange(readFromDisk: true)
            }
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [dirPath as CFString] as CFArray,
            UInt64(kFSEventStreamEventIdSinceNow),
            0.3,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    // MARK: - Change Detection

    private func checkForDefaultBrowserChange(readFromDisk: Bool) {
        let current = readFromDisk
            ? browserManager.currentDefaultBrowserFromDisk()
            : browserManager.currentDefaultBrowser()
        if let current, current.lowercased() != lastKnownDefault?.lowercased() {
            lastKnownDefault = current
            updateMenuBarIcon(bundleIdentifier: current)
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
        lastKnownDefault = browserManager.currentDefaultBrowser()
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

        menu.addItem(.separator())
        let loginItem = NSMenuItem(
            title: "Start on Login",
            action: #selector(toggleLoginItem(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = loginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

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
        waitForBrowserChange(attempts: 20)
    }

    private func waitForBrowserChange(attempts: Int, current: Int = 0) {
        guard current < attempts else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let actual = self.browserManager.currentDefaultBrowser()
            if let actual, actual.lowercased() != self.lastKnownDefault?.lowercased() {
                self.lastKnownDefault = actual
                self.updateMenuBarIcon()
            } else {
                self.waitForBrowserChange(attempts: attempts, current: current + 1)
            }
        }
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        loginItemManager.toggle()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Menubar Icon

    private func updateMenuBarIcon(bundleIdentifier: String) {
        guard let button = statusItem.button else { return }
        button.image = browserManager.iconForBrowser(bundleIdentifier: bundleIdentifier)
        button.image?.isTemplate = false
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        button.image = browserManager.currentDefaultBrowserIcon()
        button.image?.isTemplate = false
    }
}
