import AppKit
import ApplicationServices

/// ⌥ + Tab kancası.
///
/// - `onTab(shift:)`: Tab basıldı (⇧ ile geri)
/// - `onArrow(left:)`: ← / → basıldı
/// - `onOptionReleased()`: ⌥ bırakıldı → seçimi uygula
/// - `onCommit()`: Return
/// - `onCancel()`: Esc
/// - `onToggle()`: ⌥+Tab ilk tetikleme
///
/// Teknik not: CGEventTap global çalışır ve gerekirse tuşu yutar, bu yüzden panel key window olmak zorunda değil.
/// Tam ekran uygulamalarda da çalışır. Erişilebilirlik izni gerektirir.
final class HotKeyMonitor {

    var onFirstSummon: (() -> Void)?
    var onTab: ((Bool) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onOptionReleased: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isActive = false
    private var optionWasDown = false

    private let tabKeyCode: Int64 = 48        // kVK_Tab
    private let escapeKeyCode: Int64 = 53     // kVK_Escape
    private let returnKeyCode: Int64 = 36     // kVK_Return
    private let leftArrowKeyCode: Int64 = 123
    private let rightArrowKeyCode: Int64 = 124

    // MARK: - Kurulum

    func start() {
        guard eventTap == nil else { return }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: mask,
                                          callback: hotKeyCallback,
                                          userInfo: refcon) else {
            NSLog("AltTabPersonal: event tap oluşturulamadı (erişilebilirlik izni gerekiyor)")
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

    /// İzleyici aktif mi (⌥ basılı tutuluyor ve panel açık).
    func setActive(_ active: Bool) {
        isActive = active
        if !active { optionWasDown = false }
    }

    // MARK: - Olay işleme

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let optionDown = flags.contains(.maskAlternate)
        let shiftDown = flags.contains(.maskShift)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .flagsChanged {
            // ⌥ bırakıldı → seçimi uygula
            if isActive, optionWasDown, !optionDown {
                optionWasDown = false
                DispatchQueue.main.async { [weak self] in self?.onOptionReleased?() }
                return nil
            }
            optionWasDown = optionDown
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        // ⌥ basılı değilse ve panel kapalıysa: sadece ⌥+Tab başlangıcını yakala.
        if !isActive {
            if optionDown, keyCode == tabKeyCode {
                optionWasDown = true
                DispatchQueue.main.async { [weak self] in self?.onFirstSummon?() }
                return nil   // tuşu yut: başka uygulama görmesin
            }
            return Unmanaged.passUnretained(event)
        }

        // Panel açıkken gezinme tuşları
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
            return nil   // panel açıkken diğer tuşları yut
        }
    }
}

/// CGEventTap C callback'i — global fonksiyon olmak zorunda (closure capture edemez).
private func hotKeyCallback(proxy: CGEventTapProxy,
                            type: CGEventType,
                            event: CGEvent,
                            refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
