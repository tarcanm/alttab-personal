import AppKit
import ApplicationServices

/// Selection state and raising windows.
/// Seçim durumu ve pencere öne getirme.
final class SwitcherController {

    private let panel = SwitcherPanel()
    private var windows: [WindowInfo] = []
    private var selectedIndex = 0
    private var isShowing = false
    private var summonScreen: NSScreen?

    // MARK: - Flow called from the hotkey monitor / Kancadan çağrılan akış

    func handleFirstSummon() {
        summonScreen = NSScreen.main
        refresh()
        guard !windows.isEmpty else {
            NSSound.beep()
            return
        }
        // Windows behaviour on the first press: select the next window (index 1).
        // İlk basışta Windows mantığı: bir sonraki pencere (index 1).
        selectedIndex = windows.count > 1 ? 1 : 0
        show()
    }

    func handleTab(shift: Bool) {
        guard isShowing, !windows.isEmpty else { return }
        cycle(by: shift ? -1 : 1)
    }

    func commit() {
        guard isShowing else { return }
        let target = windows.indices.contains(selectedIndex) ? windows[selectedIndex] : nil
        hide()
        if let target { activate(target) }
    }

    func cancel() {
        hide()
    }

    // MARK: - Internals / İç işleyiş

    private func refresh() {
        windows = WindowEnumerator.list()
        selectedIndex = 0
    }

    private func show() {
        isShowing = true
        panel.render(windows: windows, selectedIndex: selectedIndex)
        panel.showPanel(centeredOn: summonScreen)
    }

    private func hide() {
        isShowing = false
        panel.orderOut(nil)
    }

    private func cycle(by delta: Int) {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + windows.count) % windows.count
        panel.render(windows: windows, selectedIndex: selectedIndex)
        panel.showPanel(centeredOn: summonScreen)
    }

    private func activate(_ window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }

        // Un-minimize if needed.
        // Küçültülmüşse geri aç.
        if window.isMinimized {
            AXUIElementSetAttributeValue(window.axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        // Raise the window.
        // Pencereyi öne getir.
        AXUIElementPerformAction(window.axWindow, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window.axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)

        // Activate the owning application.
        // Uygulamayı aktive et.
        app.activate(options: [.activateIgnoringOtherApps])
    }
}
