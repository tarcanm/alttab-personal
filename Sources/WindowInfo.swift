import AppKit
import ApplicationServices

/// Listelenecek tek bir pencere.
struct WindowInfo {
    let pid: pid_t
    let appName: String
    let appIcon: NSImage?
    let title: String
    let isMinimized: Bool
    let axWindow: AXUIElement

    /// Panelde gösterilecek etiket.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "\(appName) (başlıksız pencere)" }
        return trimmed
    }
}
