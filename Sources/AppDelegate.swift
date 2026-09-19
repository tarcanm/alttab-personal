import AppKit

/// Owns the status bar item, the permission flow and the wiring between the hotkey monitor and
/// the switcher controller.
///
/// Menü çubuğu simgesini, izin akışını ve kanca ile denetleyici arasındaki bağlantıları yönetir.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let controller = SwitcherController()
    private let hotKeys = HotKeyMonitor()
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        wireHotKeys()
        hotKeys.start()

        if !Permissions.hasAccessibility {
            Permissions.promptAccessibility()
            startPermissionWatch()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys.stop()
        permissionTimer?.invalidate()
    }

    // MARK: - Setup / Kurulum

    private func wireHotKeys() {
        hotKeys.onFirstSummon = { [weak self] in
            self?.hotKeys.setActive(true)
            self?.controller.handleFirstSummon()
        }
        hotKeys.onTab = { [weak self] shift in self?.controller.handleTab(shift: shift) }
        hotKeys.onModifierReleased = { [weak self] in
            self?.hotKeys.setActive(false)
            self?.controller.commit()
        }
        hotKeys.onCommit = { [weak self] in
            self?.hotKeys.setActive(false)
            self?.controller.commit()
        }
        hotKeys.onCancel = { [weak self] in
            self?.hotKeys.setActive(false)
            self?.controller.cancel()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⇥"
        item.button?.toolTip = "AltTab Personal"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L.menuHint, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L.menuPermissions, action: #selector(openPermissions), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L.menuLogs, action: #selector(openLog), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L.menuQuit, action: #selector(quit), keyEquivalent: "q"))
        for menuItem in menu.items where menuItem.action != nil { menuItem.target = self }

        item.menu = menu
        statusItem = item
    }

    /// Poll every 2 seconds until the permission is granted, then re-create the event tap.
    /// İzin verilene kadar her 2 saniyede kontrol et, verilince kancayı yeniden kur.
    private func startPermissionWatch() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else { return }
            if Permissions.hasAccessibility {
                timer.invalidate()
                self.permissionTimer = nil
                self.hotKeys.stop()
                self.hotKeys.start()
            }
        }
    }

    // MARK: - Menu actions / Menü eylemleri

    @objc private func openPermissions() {
        Permissions.openAccessibilitySettings()
    }

    @objc private func openLog() {
        let logDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        NSWorkspace.shared.open(logDir)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
