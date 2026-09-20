# AltTab Personal for Linux (X11) / Linux sürümü (X11)

Hold `Alt`, press `Tab`, release to switch. Same behaviour as the macOS version, written against
X11 instead of AppKit. No new packages: it uses what a Debian/Fluxbox desktop already ships
(`python3-gi`, `gir1.2-wnck-3.0`, `python3-xlib`).

`Alt` basılı tut, `Tab`a bas, bırakınca geç. macOS sürümüyle aynı davranış, AppKit yerine X11 ile
yazıldı. Yeni paket gerekmez: Debian/Fluxbox masaüstünde zaten olanı kullanır (`python3-gi`,
`gir1.2-wnck-3.0`, `python3-xlib`).

## Keys / Tuşlar

| Key / Tuş | Action / Eylem |
|---|---|
| `Alt` + `Tab` | open the panel, select the previous window / paneli aç, bir önceki pencereyi seç |
| `Tab` / `Shift`+`Tab` | forward / backward / ileri / geri |
| `←` / `→` | backward / forward / geri / ileri |
| release `Alt` or `Return` | raise the selected window / seçili pencereyi öne al |
| `Esc` | cancel / iptal |

## Install / Kurulum

The installer detects your session and window manager, then does the right thing for that desktop.
Kurulum betiği oturumunu ve pencere yöneticini tespit eder, sonra o masaüstü için doğru olanı yapar.

```bash
git clone https://github.com/tarcanm/alttab-personal.git
cd alttab-personal/linux
bash install.sh              # install / update / kur / güncelle
bash install.sh --start      # install and start it now / kur ve hemen başlat
bash install.sh --check      # report only, change nothing / sadece rapor, hiçbir şeyi değiştirmez
bash install.sh --wm fluxbox # force a desktop if detection gets it wrong / yanlış tespit ederse zorla
```

No `git` on that machine? / O makinede `git` yoksa:

```bash
curl -fsSL https://github.com/tarcanm/alttab-personal/archive/refs/heads/main.tar.gz | tar xz -C /tmp
bash /tmp/alttab-personal-main/linux/install.sh
```

Run it **as your desktop user, inside the graphical session** — not as root, not from a TTY.
**Masaüstü kullanıcın olarak, grafik oturumun içinde** çalıştır — root olarak değil, TTY'den değil.

**What it handles per desktop / Masaüstüne göre yaptıkları**

| Desktop / Masaüstü | Frees Alt+Tab / Alt+Tab'ı serbest bırakır | Autostart / Otomatik başlatma |
|---|---|---|
| Fluxbox | yes — delegates to the proven `setup-fluxbox.sh` / kanıtlanmış betiğe devreder | `~/.fluxbox/startup` |
| XFCE (xfwm4) | yes — `xfconf-query` / evet | `~/.config/autostart/` |
| MATE (marco) | yes — `gsettings` / evet | `~/.config/autostart/` |
| Cinnamon (muffin) | yes — `gsettings` / evet | `~/.config/autostart/` |
| GNOME (mutter) | yes — `gsettings` / evet | `~/.config/autostart/` |
| KDE (KWin) | manual: System Settings → Shortcuts / elle | `~/.config/autostart/` |
| Openbox | Alt+Tab is not bound by default / varsayılan olarak bağlı değil | `~/.config/autostart/` |
| i3, sway, JWM, IceWM, others | manual / elle | `~/.config/autostart/` |

The installer also checks that **Alt is on Mod1** and repairs that mapping (a session where `mod1` is
empty makes Alt+Tab impossible — the same bug that killed Fluxbox's own `Mod1+Tab` on MX Linux).
Kurulum ayrıca **Alt tuşunun Mod1'de olduğunu** kontrol eder ve gerekirse düzeltir (`mod1` boşken
Alt+Tab imkânsızdır — MX Linux'ta Fluxbox'ın kendi `Mod1+Tab`'ını öldüren aynı hata).

**Wayland:** not supported. The app grabs Alt+Tab on the X11 display, so use an X11/Xorg session.
**Wayland:** desteklenmez. Uygulama Alt+Tab'ı X11 ekranında tutar; X11/Xorg oturumu kullan.

**Uninstall / Kaldırma**

```bash
rm -rf ~/.alttab-linux ~/.config/autostart/alttab-personal.desktop
# Fluxbox also: remove the AltTab block from ~/.fluxbox/startup and restore ~/.fluxbox/keys.bak-*
```

## Run / Çalıştırma

```bash
bash setup-fluxbox.sh            # Fluxbox only, the original script / sadece Fluxbox, özgün betik
bash setup-fluxbox.sh --start    # ...and start the app / ...ve uygulamayı başlat
./run.sh                         # start the switcher / değiştiriciyi başlat
./run.sh --print-windows         # dump the window list and exit / listeyi yaz ve çık
./run.sh --demo-panel 5          # show the panel for 5s without grabbing the key / tuşu al- madan paneli göster
./run.sh --version
python3 tests/test_logic.py      # offline tests, no X11 needed / çevrimdışı testler
```

Autostart: on Fluxbox `install.sh` writes a marked block into `~/.fluxbox/startup` **before** the
`exec fluxbox` line — `/usr/bin/startfluxbox` execs that file, so anything placed after the window
manager call never runs — and on the other desktops it writes
`~/.config/autostart/alttab-personal.desktop`. By hand it is the same: put the launcher before
`exec fluxbox` in `~/.fluxbox/startup`, or copy `alttab-personal.desktop` to `~/.config/autostart/`.

Otomatik başlatma: Fluxbox'ta `install.sh`, `~/.fluxbox/startup` içine işaretli bir blok yazar ve blok
`exec fluxbox` satırından **önce** gelir — `/usr/bin/startfluxbox` o dosyayı exec eder, yani pencere
yöneticisi çağrısından sonra konan hiçbir satır çalışmaz. Diğer masaüstlerinde
`~/.config/autostart/alttab-personal.desktop` yazılır. Elle yapmak da aynı: başlatıcıyı
`~/.fluxbox/startup` içinde `exec fluxbox`'tan önce koy, ya da `.desktop` dosyasını
`~/.config/autostart/` altına kopyala.

## Testing / Test

```bash
python3 tests/test_logic.py        # pure helpers, no X11 / saf yardımcılar, X11 yok
python3 tests/test_imports.py      # every module imports / tüm modüller import edilebilir
python3 tests/test_hotkey_logic.py # key routing with fake events / sahte olaylarla tuş yönlendirme
python3 tests/flow_check.py [i]    # real display: raise window i / gerçek ekran: i'inci pencereyi öne al
DISPLAY=:0 python3 tests/test_live_display.py  # real X calls / gerçek X çağrıları (stop the app first / önce uygulamayı durdur)
bash check-install.sh              # is the installation healthy? / kurulum sağlıklı mı?
python3 -m doctest logic.py        # doctests inside logic.py / logic.py içindeki doctestler
./run.sh --print-windows           # dump the live window list / canlı pencere listesini yaz
./run.sh --demo-panel 5            # show the panel without the hotkey / kanca olmadan paneli göster
```

**What the tests do not cover / Testlerin kapsamadığı yer:** key injection cannot verify the hotkey.
On X.Org 21 the XTest-generated events used by automation tools do not activate a passive
`XGrabKey` grab at all (verified here: even a modifier-less `F9` grab received nothing), so the
"press Alt+Tab" path has to be checked by hand. Everything downstream of the grab (start, cycle,
commit, cancel, alt-release, auto-repeat) is covered by `tests/test_hotkey_logic.py`.
Bu sunucuda otomasyon araçlarının kullandığı XTest olayları pasif `XGrabKey` grab'ini hiç
tetiklemiyor (burada doğrulandı: modifier'sız `F9` grab'i bile olay almadı), bu yüzden "Alt+Tab'a
bas" yolu elle denenmeli. Grab'den sonraki her şey (başlatma, gezinme, onaylama, iptal, Alt bırakma,
tuş tekrarı) `tests/test_hotkey_logic.py` ile kapsanıyor.

## The Alt+Tab conflict / Alt+Tab çakışması

Fluxbox binds `Mod1 Tab` to `NextWindow` from its compiled-in defaults, and X gives a key
combination to one client only. That is why the setup script neutralises those lines in
`~/.fluxbox/keys` and reloads the window manager. If the combination is still taken when the app
starts — the usual case at login, while the window manager is still binding its keys — the app stays
alive and retries with backoff (0.25s, 0.5s, 1s … 30s) instead of exiting, and re-installs the grab
on X `MappingNotify`, so an `xmodmap` change or a window manager reloading its keys is picked up
without a restart.

Fluxbox, `Mod1 Tab` kombinasyonunu derlenmiş varsayılanlarla `NextWindow`'a bağlar ve X bir kombinasyonu
tek bir istemciye verir. Bu yüzden kurulum betiği `~/.fluxbox/keys` içindeki o satırları etkisiz hale
getirip pencere yöneticisini yeniler. Kombinasyon uygulama başlarken hâlâ başkasındaysa — giriş
anında, pencere yöneticisi tuşlarını bağlarken sık görülür — uygulama çıkmak yerine yaşamaya devam
eder ve artan aralıklarla (0.25s, 0.5s, 1s … 30s) tekrar dener; X `MappingNotify` geldiğinde grab'i
yeniden kurar, yani `xmodmap` değişikliği ya da pencere yöneticisinin tuşları yeniden yüklemesi
yeniden başlatmaya gerek kalmadan yakalanır.

## When Alt is not Mod1 / Alt Mod1 değilse

A grab on `Mod1+Tab` succeeds even when **no key produces Mod1**, so the app looks healthy while
Alt+Tab does nothing. This really happened here: `mod1` was empty and `Alt_L (0x40)` sat inside
`control`, which also meant Fluxbox's own `Mod1 Tab :NextWindow` binding had never fired. Check with
`xmodmap -pm`; the app also prints a warning with the repair command when it detects this.

`Mod1+Tab` üzerine grab, **hiçbir tuş Mod1 üretmese bile** başarılı olur; yani uygulama sağlıklı
görünürken Alt+Tab hiçbir şey yapmaz. Bu tam olarak burada yaşandı: `mod1` boştu ve `Alt_L (0x40)`
`control` grubundaydı; bu yüzden Fluxbox'ın kendi `Mod1 Tab :NextWindow` bağlaması da hiç çalışmamıştı.
`xmodmap -pm` ile kontrol edin; uygulama bunu algıladığında düzeltme komutuyla birlikte uyarı yazar.

```bash
xmodmap -e "clear control" -e "add control = Control_L Control_R" \
        -e "clear mod1"    -e "add mod1 = Alt_L"
```

`setup-fluxbox.sh` applies this when needed and writes the same guarded repair into
`~/.fluxbox/startup`, so a login that breaks the map again repairs itself.
`setup-fluxbox.sh` gerektiğinde bunu uygular ve aynı korumalı onarımı `~/.fluxbox/startup` dosyasına
yazar; haritayı tekrar bozan bir giriş kendini onarır.

## Design notes / Tasarım notları

- A passive grab on `Mod1+Tab` (plus the `Lock`/`Mod2` variants so NumLock does not break it) receives
  the first press; an active keyboard grab then routes every key to us while the panel is open.
  Pasif grab `Mod1+Tab` ilk basışı alır (NumLock bozmasın diye `Lock`/`Mod2` varyasyonlarıyla); panel
  açıkken aktif klavye grab'i tüm tuşları bize yönlendirir.
- Alt release is detected from the `KeyRelease` event and, as ground truth, from a `QueryKeymap` poll.
  Alt bırakılması `KeyRelease` olayından ve kesin bilgi olarak `QueryKeymap` yoklamasından alınır.
- Window order comes from `_NET_CLIENT_LIST_STACKING` (EWMH: bottom-to-top, reversed), with the active
  window first. That is a stand-in for true MRU history, which is on the roadmap.
  Pencere sırası `_NET_CLIENT_LIST_STACKING`'ten gelir (EWMH: aşağıdan yukarıya, ters çevrilir), aktif
  pencere başta. Bu, gerçek MRU geçmişinin yerine geçen bir yaklaşımdır; MRU yol haritasında.
- No compositor is assumed, so the panel is opaque and has no blur or rounded corners. Fluxbox here
  has `compton` installed but not running.
  Kompozitör varsayılmaz; panel opak, bulanıklık ve yuvarlak köşe yok. Buradaki Fluxbox'ta `compton`
  kurulu ama çalışmıyor.
- X11 only. Wayland forbids global key grabs and foreign-window control, so this design cannot work
  there without a portal-based rewrite.
  Sadece X11. Wayland global tuş grab'ine ve başka pencereleri yönetmeye izin vermez; portal tabanlı
  yeniden yazım olmadan bu tasarım çalışmaz.

## Files / Dosyalar

| File | Purpose / Amaç |
|---|---|
| `alttab_personal.py` | entry point, switcher flow / giriş noktası, akış |
| `logic.py` | pure helpers, unit tested / saf yardımcılar, testli |
| `l.py` | English/Turkish strings / İngilizce-Türkçe metinler |
| `x11_hotkey.py` | global Alt+Tab grab / global Alt+Tab kancası |
| `window_list.py` | window list and activation via libwnck / liste ve aktivasyon |
| `panel.py` | GTK panel / GTK panel |
| `run.sh` | launcher / başlatıcı |
| `setup-fluxbox.sh` | one-time Fluxbox setup / tek seferlik Fluxbox kurulumu |
| `check-install.sh` | installation health check / kurulum sağlık kontrolü |
| `COMMANDS.md` | command reference / komut listesi |
| `alttab-personal.desktop` | autostart entry / otomatik başlatma |
| `tests/test_logic.py` | offline tests / çevrimdışı testler |
| `tests/test_live_display.py` | real X tests, skipped without a display / gerçek X testleri, ekran yoksa atlanır |
