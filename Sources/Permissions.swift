import AppKit
import ApplicationServices

enum Permissions {

    /// Erişilebilirlik (Accessibility) izni verilmiş mi?
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Sistemin izin diyaloğunu gösterir (bir kez gösterilir).
    static func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// System Settings → Privacy & Security → Accessibility ekranını açar.
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
