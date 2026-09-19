import AppKit

/// Panel that shows the window list. Borderless, floating, above all Spaces and full-screen apps.
/// Pencere listesini gösteren panel. Borderless, floating, tüm Spaces ve tam ekran uygulamaların üstünde.
final class SwitcherPanel: NSPanel {

    private let effectView = NSVisualEffectView()
    private let stack = NSStackView()
    private var rows: [RowView] = []

    private let rowHeight: CGFloat = 38
    private let panelWidth: CGFloat = 560
    private let maxVisibleRows = 12

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 200),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        animationBehavior = .none

        // Blurred background like a popover.
        // Popover gibi bulanık arka plan.
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -10),
        ])
        contentView = effectView
    }

    // The panel never takes focus; the event tap handles all keys.
    // Panel hiç odak almaz; tuşları event tap yönetir.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Rendering / Gösterim

    func render(windows: [WindowInfo], selectedIndex: Int) {
        // Clear everything from the previous render (rows, spacer, hint label).
        // Önceki render'dan kalan her şeyi temizle (satırlar, boşluk, ipucu etiketi).
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        rows.removeAll()

        // Keep the selected row in the middle of the visible window.
        // Seçili satırı görünür pencerenin ortasında tut.
        let start = max(0, min(selectedIndex - maxVisibleRows / 2, windows.count - maxVisibleRows))
        let end = min(windows.count, start + maxVisibleRows)
        let visible = Array(windows[start..<end])

        for (offset, window) in visible.enumerated() {
            let globalIndex = start + offset
            let row = RowView(window: window, isSelected: globalIndex == selectedIndex)
            row.widthAnchor.constraint(equalToConstant: panelWidth - 24).isActive = true
            rows.append(row)
            stack.addArrangedSubview(row)
        }

        let height = CGFloat(min(windows.count, maxVisibleRows)) * rowHeight + 24
        setContentSize(NSSize(width: panelWidth, height: max(height, 80)))

        if windows.count > maxVisibleRows {
            stack.addArrangedSubview(hintLabel(L.windowCount(total: windows.count, shown: visible.count)))
        }
        stack.addArrangedSubview(hintLabel(L.navigationHint))
    }

    private func hintLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        return label
    }

    /// Centers the panel on the given screen (or the main screen).
    /// Paneli verilen ekranda (yoksa ana ekranda) ortalar.
    func showPanel(centeredOn screen: NSScreen?) {
        let target = screen ?? NSScreen.main
        guard let frame = target?.visibleFrame else { show(); return }
        let size = frame.size
        let origin = NSPoint(x: frame.origin.x + (size.width - self.frame.width) / 2,
                             y: frame.origin.y + (size.height - self.frame.height) / 2)
        setFrameOrigin(origin)
        orderFrontRegardless()
    }
}

/// One row: app icon + window title + app name.
/// Tek satır: uygulama simgesi + pencere başlığı + uygulama adı.
private final class RowView: NSView {

    init(window: WindowInfo, isSelected: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 500, height: 34))
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = (isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.85)
                                             : NSColor.clear).cgColor

        let iconView = NSImageView()
        iconView.image = window.appIcon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let title = NSTextField(labelWithString: window.displayTitle)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.textColor = isSelected ? .white : .labelColor
        title.lineBreakMode = .byTruncatingTail

        let subtitle = window.isMinimized ? "\(window.appName) (\(L.minimized))" : window.appName
        let app = NSTextField(labelWithString: subtitle)
        app.font = .systemFont(ofSize: 11)
        app.textColor = isSelected ? NSColor.white.withAlphaComponent(0.8) : .secondaryLabelColor

        let text = NSStackView(views: [title, app])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 0

        let row = NSStackView(views: [iconView, text])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        heightAnchor.constraint(equalToConstant: 34).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported / desteklenmiyor")
    }
}
