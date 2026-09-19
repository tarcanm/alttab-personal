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

## Run / Çalıştırma

```bash
bash setup-fluxbox.sh            # Fluxbox: free Alt+Tab, install, autostart / Alt+Tab'ı al, kur
bash setup-fluxbox.sh --start    # ...and start the app / ...ve uygulamayı başlat
./run.sh                         # start the switcher / değiştiriciyi başlat
./run.sh --print-windows         # dump the window list and exit / listeyi yaz ve çık
./run.sh --demo-panel 5          # show the panel for 5s without grabbing the key / tuşu al- madan paneli göster
./run.sh --version
python3 tests/test_logic.py      # offline tests, no X11 needed / çevrimdışı testler
```

Autostart: copy `alttab-personal.desktop` to `~/.config/autostart/`, or add
`~/.alttab-linux/run.sh &` to `~/.fluxbox/startup`.

Otomatik başlatma: `alttab-personal.desktop` dosyasını `~/.config/autostart/` altına kopyala, ya da
`~/.fluxbox/startup` içine `~/.alttab-linux/run.sh &` satırını ekle.

## The Alt+Tab conflict / Alt+Tab çakışması

Fluxbox binds `Mod1 Tab` to `NextWindow` from its compiled-in defaults, and X gives a key
combination to one client only. That is why the setup script neutralises those lines in
`~/.fluxbox/keys` and reloads the window manager. Without that step the app exits with the message
in `L.grab_unavailable`.

Fluxbox, `Mod1 Tab` kombinasyonunu derlenmiş varsayılanlarla `NextWindow`'a bağlar ve X bir kombinasyonu
tek bir istemciye verir. Bu yüzden kurulum betiği `~/.fluxbox/keys` içindeki o satırları etkisiz hale
getirip pencere yöneticisini yeniler. O adım olmadan uygulama `L.grab_unavailable` mesajıyla çıkar.

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
| `alttab-personal.desktop` | autostart entry / otomatik başlatma |
| `tests/test_logic.py` | offline tests / çevrimdışı testler |
