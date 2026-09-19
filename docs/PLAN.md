# AltTab Personal — Plan / Plan

> **Decision (2026-09-19):** personal use. Not submitted to the App Store, not sold, no pricing.
> Consequence: no sandbox, no notarization, private APIs are allowed, ad-hoc signing is enough.
>
> **Karar (19 Eyl 2026):** kişisel kullanım. App Store'a gönderilmeyecek, satılmayacak, fiyatlandırma yok.
> Sonuç: sandbox yok, notarization yok, özel API kullanımı serbest, ad-hoc imza yeterli.

## Why this decision removes most of the friction / Bu karar neden işi kolaylaştırıyor

| Topic / Konu | Store version / Mağaza sürümü | Personal / Kişisel sürüm |
|---|---|---|
| Sandbox | Required, window control limited / Zorunlu, pencere kontrolü kısıtlı | None, AX API free / Yok, AX API serbest |
| Notarization | Developer account + fee | None, `codesign -s -` is enough |
| Private APIs | Rejection risk / Red riski | Allowed / Serbest |
| Review time / İnceleme | Days / Günler | None / Yok |
| Distribution / Dağıtım | App Store Connect | `make run` |

## v0.1 scope / kapsam

- Hold `⌘` + press `Tab` to open the panel; `Tab` / `⇧ Tab` / `←` / `→` navigate; release `⌘` to raise;
  `Esc` cancels
- Window list via the AX API (app name, window title, icon, minimized state)
- Un-minimize a minimized window when selected
- Menu bar item + permission flow

Turkish:
- `⌘ + Tab` ile panel açma, `Tab`/`⇧Tab`/`←`/`→` gezinme, `⌘` bırakınca öne getirme, `Esc` iptal
- AX API ile açık pencere listesi (uygulama adı, pencere başlığı, simge, küçültülmüş durumu)
- Küçültülmüş pencereyi geri açma
- Menü çubuğu simgesi + izin akışı

## v0.2 — next step / sonraki adım

1. **Thumbnail previews / Küçük önizleme.** On macOS 14: `ScreenCaptureKit` (`SCShareableContent` +
   `SCScreenshotManager`), or the older `CGWindowListCreateImage` (deprecated but working).
   Requires the **Screen Recording** permission.
   macOS 14'te `ScreenCaptureKit`, ya da eski `CGWindowListCreateImage` (deprecated ama çalışıyor).
   **Ekran Kaydı izni** gerektirir.
2. **Most-recently-used ordering / Son kullanılan sırası (MRU).** Today the order is: frontmost app's
   windows first, then running-application order. MRU needs activation tracking via
   `NSWorkspace.didActivateApplicationNotification`, persisted in `UserDefaults`.
3. **Group windows per app / Aynı uygulamanın pencerelerini gruplama.** Like AltTab: five windows of one
   app on a single row, expanding on hover.
4. **Panel placement / Panel konumu.** Currently screen center. Windows-style: the screen under the
   cursor, fixed mid-screen size.

## v0.3

- Type-to-search (keys are already captured; a `query` buffer plus filtering is enough)
  / Yazmaya başlayınca arama (tuş yakalama zaten var, bir `query` tamponu yeterli)
- A shortcut recorder. Today only the modifier is configurable (`defaults write
  online.plner.alttab-personal modifier -string option` switches to `⌥`); a full key recorder with a
  preferences window is still to come.
- Multi-display: open on the display with the cursor / Çoklu ekran: imlecin olduğu ekranda aç
- Make the small-window filter threshold configurable (currently fixed 200x120)
  / Küçük pencere filtresi eşiği ayarlanabilir olsun

## Known limitations (v0.1) / Bilinen sınırlar

- Ad-hoc signing means macOS may ask for the Accessibility permission again after every rebuild.
  Fix (v0.2): sign with a local developer certificate so the TCC identity stays stable.
  Ad-hoc imza yüzünden her yeniden derlemede macOS erişilebilirlik iznini yeniden isteyebilir.
- No thumbnails, no search, no grouping yet (v0.2/v0.3). / Thumbnail, arama, gruplama yok.
- Multi-window apps such as Excel or Photoshop may report empty AX titles; the panel then shows
  `<app> (Untitled window)`.
  Çok pencereli uygulamalarda pencere başlıkları AX'ten boş gelebilir; o durumda `<uygulama> (Başlıksız pencere)`.
- The panel is declared `fullScreenAuxiliary`, so it appears over full-screen apps; a few games with
  their own full-screen mode may still hide it.
  Tam ekran uygulamaların üstünde panel görünür, ancak bazı oyunlar kendi modlarında gizleyebilir.

## Language / Dil

Everything in this repo is written in two languages: **English first, Turkish second**. Source comments,
this plan and the README follow the same order. The app's own labels follow the macOS preferred language
(Turkish when it starts with `tr`, otherwise English) through the small helper in `Sources/L.swift`.

Bu repodaki her şey iki dilde: **önce İngilizce, sonra Türkçe**. Kaynak kod yorumları, bu plan ve README
aynı sırayı izler. Uygulamanın kendi etiketleri, `Sources/L.swift` içindeki küçük yardımcı sayesinde
macOS'un tercih edilen diline uyar (dil `tr` ile başlıyorsa Türkçe, aksi halde İngilizce).
