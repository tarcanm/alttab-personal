import AppKit
import ApplicationServices

/// A single window that can appear in the switcher list.
/// Listelenecek tek bir pencere.
struct WindowInfo {
    let pid: pid_t
    let appName: String
    let appIcon: NSImage?
    let title: String
    let isMinimized: Bool
    let axWindow: AXUIElement

    /// Label shown in the panel.
    /// Panelde gösterilecek etiket.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "\(appName) (\(L.untitledWindow))" }
        return trimmed
    }
}
