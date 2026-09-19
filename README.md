# AltTab Personal

Windows tarzı pencere değiştirici (AltTab benzeri), **kişisel kullanım** için. App Store yok, sandbox yok,
notarization yok, fiyatlandırma yok. Sadece kendi MacBook'unda çalışacak.

> **Kimin için:** Mustafa (M1 MacBook, macOS 14+)
> **Hedef:** `⌥ Option + Tab` ile açık pencereler arasında Windows tarzı gezinme, seçip öne getirme.

## Ne yapıyor (v0.1)

- `⌥ + Tab` basılı tutunca ekranda pencere listesi açılır
- `⌥` basılıyken `Tab` ileri, `⇧ Tab` geri, `←/→` ile de gezinme
- `⌥` bırakınca (veya `Return`) seçili pencere öne gelir; simge durumundaki pencere geri açılır
- `Esc` iptal eder
- Menü çubuğunda küçük bir simge: yenile / izinler / çıkış

Thumbnail (küçük önizleme), uygulama bazlı gruplama ve arama v0.2+ içinde (aşağıdaki yol haritasına bak).

## Gereksinimler

- macOS 14 (Sonoma) veya üzeri
- Xcode **veya** sadece Command Line Tools (`xcode-select --install`). İkincisi yeterli, çünkü derleme `make` ile `swiftc` üzerinden yapılıyor.
- **Erişilebilirlik izni** (System Settings → Privacy & Security → Accessibility). Global klavye kancası ve pencere
  listesi bu izni gerektirir. Uygulama ilk açılışta izni sorar.

## Derleme ve çalıştırma (Makefile yolu, Xcode projesi gerekmez)

```bash
git clone https://github.com/tarcanm/alttab-personal.git
cd alttab-personal
make app      # build/AltTabPersonal.app üretir + ad-hoc imzalar
make run      # derler ve açar
```

Xcode projesi istersen (XcodeGen kuruluysa):

```bash
brew install xcodegen
xcodegen generate
open AltTabPersonal.xcodeproj
```

## İzin akışı (ilk açılışta bir kez)

1. `make run` → uygulama açılır, hem pencere listesi boş olabilir hem de sistem izni sorabilir
2. System Settings → **Privacy & Security → Accessibility** → *AltTabPersonal*'ı aç (listede yoksa `+` ile `build/AltTabPersonal.app` seç)
3. Uygulamayı kapat-aç (izin değişimi yeniden başlatma ister)
4. `⌥ + Tab` çalışır

Not: ad-hoc imzalı olduğu için, uygulamayı yeniden derlediğinde macOS izni bazen yeniden ister. Her seferinde
`+` ile tekrar eklemek zorunda kalırsan, `setup_local_signing.sh` (v0.2) ile kendi geliştirici sertifikanı kullanacağız.

## Sorun giderme

- **Liste boş geliyor:** Erişilebilirlik izni verilmemiş. Menü çubuğu simgesinden *Permissions…* ile ayarları aç.
- **⌥ + Tab çalışmıyor:** Başka bir uygulama bu kombinasyonu kapmış olabilir (bazı editörler). v0.2'de kısayolu
  ayarlardan değiştirilebilir yapacağız. Şimdilik `defaults write online.plner.alttab-personal hotkey -string "option+space"` ile deneyebilirsin (v0.1'de henüz okunmuyor).
- **Tam ekran uygulamalarda panel görünmüyor:** v0.1 `fullScreenAuxiliary` ile geliyor; sorun görürsen bana söyle.

## Depo yapısı

```
Sources/
  main.swift              → giriş noktası (accessory app, Dock simgesi yok)
  AppDelegate.swift       → menü çubuğu simgesi, izin akışı, bağlantılar
  Permissions.swift       → Erişilebilirlik izni kontrolü + yönlendirme
  WindowInfo.swift        → pencere modeli
  WindowEnumerator.swift  → AX API ile açık pencere listesi
  HotKeyMonitor.swift     → CGEventTap ile ⌥+Tab kancası
  SwitcherPanel.swift     → liste paneli (NSVisualEffectView + NSStackView)
  SwitcherController.swift→ seçim durumu, öne getirme
Info.plist                → LSUIElement (menü çubuğu uygulaması)
Makefile                  → swiftc ile .app üretimi + ad-hoc imza
project.yml               → opsiyonel XcodeGen projesi
docs/PLAN.md              → yol haritası
```

## Yol haritası

- **v0.1 (bu sürüm):** pencere listesi, ⌥+Tab gezinme, öne getirme, menü çubuğu simgesi
- **v0.2:** küçük önizleme (thumbnail), son kullanılan sırası, aynı uygulamanın pencerelerini gruplama
- **v0.3:** arama (yazmaya başlayınca filtre), kısayol ayarı, çoklu ekran konumlandırma
- **v0.4:** pencere kapatma / küçültme kısayolları, hariç tutulan uygulamalar listesi
