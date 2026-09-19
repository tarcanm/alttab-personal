import AppKit

// AltTab Personal — giriş noktası.
// Accessory app: Dock simgesi yok, sadece menü çubuğu simgesi.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
