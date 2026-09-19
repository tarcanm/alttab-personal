import AppKit

// AltTab Personal entry point.
// Accessory app: no Dock icon, only a menu bar item.
//
// AltTab Personal giriş noktası.
// Accessory app: Dock simgesi yok, sadece menü çubuğu simgesi.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
