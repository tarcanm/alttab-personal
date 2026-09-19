import AppKit
import ApplicationServices

/// AX API üzerinden açık pencereleri toplar.
/// Not: Erişilebilirlik izni yoksa boş liste döner (hata vermez).
enum WindowEnumerator {

    /// En öndeki uygulamanın pencereleri başta olacak şekilde pencere listesi.
    static func list() -> [WindowInfo] {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0

        var front: [WindowInfo] = []
        var rest: [WindowInfo] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            let pid = app.processIdentifier
            guard pid > 0, pid != myPID else { continue }

            let windows = windows(for: pid)
            if windows.isEmpty { continue }

            let info = windows.map { win in
                WindowInfo(pid: pid,
                           appName: app.localizedName ?? "Uygulama",
                           appIcon: app.icon,
                           title: win.title,
                           isMinimized: win.isMinimized,
                           axWindow: win.element)
            }

            if pid == frontPID { front.append(contentsOf: info) } else { rest.append(contentsOf: info) }
        }

        return front + rest
    }

    // MARK: - Private

    private struct RawWindow {
        let element: AXUIElement
        let title: String
        let isMinimized: Bool
    }

    private static func windows(for pid: pid_t) -> [RawWindow] {
        let appElement = AXUIElementCreateApplication(pid)
        guard let raw = copyAttribute(appElement, kAXWindowsAttribute as String) as? [AXUIElement] else {
            return []
        }

        var result: [RawWindow] = []
        for element in raw {
            // Sadece gerçek pencere rollerini al (sheet, popover, dialog alt pencereleri hariç tutulur).
            let role = (copyAttribute(element, kAXRoleAttribute as String) as? String) ?? ""
            if !role.isEmpty, role != (kAXWindowRole as String) { continue }

            // Çok küçük pencereleri (araç pencereleri, HUD) ele.
            if let size = size(of: element), size.width < 200 || size.height < 120 { continue }

            let title = (copyAttribute(element, kAXTitleAttribute as String) as? String) ?? ""
            let minimized = (copyAttribute(element, kAXMinimizedAttribute as String) as? Bool) ?? false
            result.append(RawWindow(element: element, title: title, isMinimized: minimized))
        }
        return result
    }

    private static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return status == .success ? value : nil
    }

    private static func size(of element: AXUIElement) -> CGSize? {
        guard let value = copyAttribute(element, kAXSizeAttribute as String) else { return nil }
        var size = CGSize.zero
        if AXValueGetValue(value as! AXValue, .cgSize, &size) { return size }
        return nil
    }
}
