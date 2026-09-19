# AltTab Personal — Plan

> **Karar (2026-09-19):** Kişisel kullanım. App Store'a gönderilmeyecek, satılmayacak, fiyatlandırma yok.
> Bu yüzden: sandbox yok, notarization yok, özel API kullanımı serbest, ad-hoc imza yeterli.

## Neden bu karar işi kolaylaştırıyor

| Konu | Mağaza sürümü olsaydı | Kişisel sürüm |
|------|------------------------|----------------|
| Sandbox | Zorunlu, pencere kontrolü kısıtlı | Yok, AX API serbest |
| Notarization | Apple Developer hesabı + ücret | Yok, `codesign -s -` yeter |
| Özel API riski | Red riski | Serbest |
| İnceleme süresi | Günler | Yok |
| Sürüm dağıtımı | App Store Connect | `make run` |

Yani AltTab'ın yaptığı şeyi yapmak için gereken teknik engellerin çoğu ortadan kalkıyor.

## v0.1 (bu commit) — kapsam

- `⌥ + Tab` ile panel açma, `Tab`/`⇧Tab`/`←`/`→` gezinme, `⌥` bırakınca öne getirme, `Esc` iptal
- AX API ile açık pencere listesi (uygulama adı, pencere başlığı, simge, küçültülmüş durumu)
- Küçültülmüş pencereyi geri açma
- Menü çubuğu simgesi + izin akışı

## v0.2 — sonraki adım (1 hafta içinde)

1. **Thumbnail önizleme.** macOS 14 için: `ScreenCaptureKit` (`SCShareableContent` + `SCScreenshotManager`)
   veya eski API `CGWindowListCreateImage` (deprecated ama çalışıyor). **Ekran Kaydı izni** gerektirir.
2. **Son kullanılan sırası (MRU).** Şu an sıra: öndeki uygulamanın pencereleri + çalışan uygulama sırası.
   MRU için pencere aktivasyonlarını `NSWorkspace.didActivateApplicationNotification` ile izleyip
   `UserDefaults`'ta tutmak gerekiyor.
3. **Aynı uygulamanın pencerelerini gruplama.** AltTab'daki gibi: bir uygulamanın 5 penceresi tek satırda,
   üzerine gelince açılıyor.
4. **Panel konumu.** Şu an ekran ortası. Windows tarzı için: imlecin bulunduğu ekran + ortada sabit boyut.

## v0.3

- Yazmaya başlayınca arama (panelde tuş yakalama zaten var, bir `query` tamponu eklemek yeterli)
- Kısayol ayarı (şu an sabit `⌥+Tab`; `UserDefaults` + `MASShortcut` benzeri basit bir kayıt)
- Çoklu ekran: imlecin olduğu ekranda aç
- Küçük pencere filtresi eşiği ayarlanabilir olsun (şu an 200x120 sabit)

## Bilinen sınırlar (v0.1)

- Ad-hoc imza yüzünden her yeniden derlemede macOS erişilebilirlik iznini yeniden isteyebilir.
  Çözüm (v0.2): kendi geliştirici sertifikası ile imzala, TCC kimliği sabitlensin.
- Thumbnail yok, arama yok, gruplama yok (v0.2/v0.3).
- Excel/Photoshop gibi çok pencereli uygulamalarda pencere başlıkları AX'ten boş gelebilir; o durumda
  `<uygulama> (başlıksız pencere)` gösterilir.
- Tam ekran uygulamaların üstünde panel görünür (`fullScreenAuxiliary`), ancak bazı oyunlar kendi
  tam ekran modlarında paneli gizleyebilir.
