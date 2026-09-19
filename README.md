# AltTab Personal

A small, dependency-free macOS window switcher with Windows-style `⌥ Option + Tab` behaviour.
Written from scratch in Swift/AppKit. No App Store, no sandbox, no notarization, no telemetry.

I built this for my own daily use, and I am publishing it because a lightweight, readable
alternative is sometimes more useful than a large one.

## Features (v0.1)

- Hold `⌥ Option` and press `Tab` to open a list of all open windows
- `Tab` next, `⇧ Tab` previous, `←` / `→` also navigate
- Release `⌥` (or press `Return`) to raise the selected window, `Esc` to cancel
- The window list comes from the Accessibility API: window title, app name, app icon, minimized state
- Selecting a minimized window un-minimizes it
- Works over full-screen apps: the keyboard hook is a `CGEventTap`, so the panel does not need focus
- Menu bar item (`⇥`) with a permissions shortcut and quit; no Dock icon

## Requirements

- macOS 14 (Sonoma) or newer
- Xcode **or** just the Command Line Tools (`xcode-select --install`). The `Makefile` path needs only `swiftc`.
- **Accessibility permission** (System Settings → Privacy & Security → Accessibility). Required for the
  global keyboard hook and for reading the window list. The app prompts for it on first launch.

## Build and run

```bash
git clone https://github.com/tarcanm/alttab-personal.git
cd alttab-personal
make app      # builds build/AltTabPersonal.app and ad-hoc signs it
make run      # builds and launches
```

Prefer an Xcode project? The repo ships an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec:

```bash
brew install xcodegen
xcodegen generate
open AltTabPersonal.xcodeproj
```

## First-run permission

1. `make run` starts the app (expect an empty window list until the permission is granted)
2. System Settings → **Privacy & Security → Accessibility** → enable *AltTabPersonal*
   (if it is not listed, add `build/AltTabPersonal.app` with `+`)
3. Quit and reopen the app (macOS requires a restart after a permission change)
4. Hold `⌥` and press `Tab`

Note: because the app is ad-hoc signed, rebuilding may make macOS ask for the permission again.
Signing with a local developer certificate, to keep the TCC identity stable, is on the roadmap.

## Troubleshooting

- **The list is empty:** Accessibility permission is missing. Use the menu bar item → *Permissions…*.
- **`⌥ + Tab` does nothing:** another app may already own that combination. Making the shortcut
  configurable is on the roadmap.
- **Panel missing over a full-screen app:** the panel is declared `fullScreenAuxiliary`; a few games
  with their own full-screen mode may still hide it. That is a known limitation of the published v0.1.

## Project layout

```
Sources/
  main.swift               entry point (accessory app, no Dock icon)
  AppDelegate.swift        status bar item, permission flow, wiring
  Permissions.swift        Accessibility check, prompt, settings deep link
  WindowInfo.swift         window model
  WindowEnumerator.swift   open window list via the AX API
  HotKeyMonitor.swift      global ⌥+Tab hook via CGEventTap
  SwitcherPanel.swift      list panel (NSVisualEffectView + NSStackView)
  SwitcherController.swift selection state, raising windows
  L.swift                  tiny localization helper (English first, Turkish second)
Info.plist                 LSUIElement, bundle metadata
Makefile                   swiftc build into a .app bundle + ad-hoc signing
project.yml                optional XcodeGen project
docs/PLAN.md               roadmap and known limitations (bilingual)
docs/PUBLISH.md            release checklist (bilingual)
```

## Language / Dil

Everything in this repository is written twice: **English first, Turkish second**. Source comments,
`docs/PLAN.md` and this README follow that order. The app's own labels come from `Sources/L.swift` and
follow the macOS preferred language: Turkish when it starts with `tr`, otherwise English.

Bu repodaki her şey iki dilde yazılıdır: **önce İngilizce, sonra Türkçe**. Kaynak kod yorumları,
`docs/PLAN.md` ve bu README aynı sırayı izler. Uygulamanın etiketleri `Sources/L.swift` içinden gelir ve
macOS'un tercih edilen diline uyar: dil `tr` ile başlıyorsa Türkçe, aksi halde İngilizce.

## Roadmap

- **v0.2:** most-recently-used ordering, thumbnail previews (ScreenCaptureKit, Screen Recording permission)
- **v0.3:** type-to-search, configurable shortcut, multi-display panel placement
- **v0.4:** close/minimize shortcuts, excluded-apps list

## License

[MIT](LICENSE). This project contains no code from [AltTab](https://github.com/lwouis/alt-tab-macos)
(which is GPL-3.0); everything here was written from scratch.

## A note on support

This is a personal project published as-is. There is no support commitment, and issues are disabled;
feel free to fork it and adapt it to your own machine.
