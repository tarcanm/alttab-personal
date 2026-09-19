import AppKit
import ApplicationServices

/// Global ⌘ + Tab hook.
///
/// Callbacks:
/// - `onFirstSummon()`: the first ⌘+Tab press, panel is not open yet
/// - `onTab(shift:)`: Tab pressed (⇧ for backwards)
/// - `onModifierReleased()`: ⌘ released → apply the selection
/// - `onCommit()`: Return
/// - `onCancel()`: Esc
///
/// Technical note: a CGEventTap runs globally and can swallow the key, so the panel does not have
/// to be the key window. It also works over full-screen apps. Requires the Accessibility permission.
///
/// Global ⌘ + Tab kancası.
///
/// Geri çağrılar:
/// - `onFirstSummon()`: ilk ⌘+Tab basışı, panel henüz açık değil
/// - `onTab(shift:)`: Tab basıldı (⇧ ile geri)
/// - `onModifierReleased()`: ⌘ bırakıldı → seçimi uygula
/// - `onCommit()`: Return
/// - `onCancel()`: Esc
///
/// Teknik not: CGEventTap global çalışır ve tuşu yutabilir, bu yüzden panelin key window olması
/// gerekmez. Tam ekran uygulamalarda da çalışır. Erişilebilirlik izni gerektirir.
final class HotKeyMonitor {

    var onFirstSummon: (() -> Void)?
    var onTab: ((Bool) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onModifierReleased: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isActive = false
    private var modifierWasDown = false

    /// The modifier that summons the panel: ⌘ Command by default, because that is what macOS itself
    /// uses. The tap swallows the combination, so the system switcher does not appear while this app
    /// runs. Restore ⌥ Option with:
    ///   defaults write online.plner.alttab-personal modifier -string option
    /// Paneli açan değiştirici: varsayılan ⌘ Command, çünkü macOS'un kendisi de bunu kullanıyor.
    /// Kanca kombinasyonu yuttuğu için bu uygulama çalışırken sistem değiştiricisi görünmez.
    /// ⌥ Option'a dönmek için:
    ///   defaults write online.plner.alttab-personal modifier -string option
    private var usesCommandModifier = true

    /// Read the preference once, at start / Tercihi bir kez, başlangıçta oku
    private func readModifierPreference() {
        usesCommandModifier = (UserDefaults.standard.string(forKey: "modifier") ?? "command")
            .lowercased() != "option"
    }

    /// Flag watched for summon and for release / Açma ve bırakma için izlenen bayrak
    private var summonFlag: CGEventFlags {
        usesCommandModifier ? .maskCommand : .maskAlternate
    }

    private let tabKeyCode: Int64 = 48        // kVK_Tab
    private let escapeKeyCode: Int64 = 53     // kVK_Escape
    private let returnKeyCode: Int64 = 36     // kVK_Return
    private let leftArrowKeyCode: Int64 = 123
    private let rightArrowKeyCode: Int64 = 124

    // MARK: - Setup / Kurulum

    func start() {
        guard eventTap == nil else { return }
        readModifierPreference()
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: mask,
                                          callback: hotKeyCallback,
                                          userInfo: refcon) else {
            NSLog("%@", L.tapCreationFailed)
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Is the monitor active (the modifier is held down and the panel open)?
    /// İzleyici aktif mi (değiştirici basılı tutuluyor ve panel açık)?
    func setActive(_ active: Bool) {
        isActive = active
        if !active { modifierWasDown = false }
    }

    // MARK: - Event handling / Olay işleme

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // macOS disabled our tap: re-enable it.
            // macOS kancayı kapattı: yeniden etkinleştir.
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let modifierDown = flags.contains(summonFlag)
        let shiftDown = flags.contains(.maskShift)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .flagsChanged {
            // Modifier released → apply the selection.
            // Değiştirici bırakıldı → seçimi uygula.
            if isActive, modifierWasDown, !modifierDown {
                modifierWasDown = false
                DispatchQueue.main.async { [weak self] in self?.onModifierReleased?() }
                return nil
            }
            modifierWasDown = modifierDown
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        // Panel closed: only watch for the start of ⌘+Tab.
        // Panel kapalıyken: sadece ⌘+Tab başlangıcını yakala.
        if !isActive {
            if modifierDown, keyCode == tabKeyCode {
                modifierWasDown = true
                DispatchQueue.main.async { [weak self] in self?.onFirstSummon?() }
                return nil   // swallow it, so the system switcher never sees it / tuşu yut
            }
            return Unmanaged.passUnretained(event)
        }

        // Panel open: navigation keys.
        // Panel açıkken gezinme tuşları.
        switch keyCode {
        case tabKeyCode:
            DispatchQueue.main.async { [weak self] in self?.onTab?(shiftDown) }
            return nil
        case leftArrowKeyCode:
            DispatchQueue.main.async { [weak self] in self?.onTab?(true) }
            return nil
        case rightArrowKeyCode:
            DispatchQueue.main.async { [weak self] in self?.onTab?(false) }
            return nil
        case escapeKeyCode:
            DispatchQueue.main.async { [weak self] in self?.onCancel?() }
            return nil
        case returnKeyCode:
            DispatchQueue.main.async { [weak self] in self?.onCommit?() }
            return nil
        default:
            return nil   // swallow other keys while the panel is open / panel açıkken diğer tuşları yut
        }
    }
}

/// CGEventTap C callback. It must be a global function because it cannot capture a closure.
/// CGEventTap C callback'i. Closure capture edemediği için global fonksiyon olmak zorunda.
private func hotKeyCallback(proxy: CGEventTapProxy,
                            type: CGEventType,
                            event: CGEvent,
                            refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
