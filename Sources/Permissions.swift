import AppKit
import ApplicationServices

/// Accessibility permission helpers.
/// Erişilebilirlik (Accessibility) izni yardımcıları.
enum Permissions {

    /// Is the Accessibility permission granted?
    /// Erişilebilirlik izni verilmiş mi?
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system permission dialog (only prompts once).
    /// Sistemin izin diyaloğunu gösterir (bir kez sorar).
    static func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings → Privacy & Security → Accessibility.
    /// System Settings → Privacy & Security → Accessibility ekranını açar.
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
