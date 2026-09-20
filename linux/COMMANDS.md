# Commands / Komutlar

Every command runs as your desktop user, inside the graphical session, never as root.
Her komut masaustu kullanicisi olarak, grafik oturumunun icinde calistirilir; root olarak degil.

## 1. Install, update and start / Kur, guncelle ve baslat

```bash
bash install.sh --start        # any desktop / her masaustu: kur, guncelle, baslat
bash install.sh --check        # report only / sadece rapor
bash install.sh --wm xfwm4     # force the desktop if detection is wrong / tespit yanlissa zorla
bash setup-fluxbox.sh --start  # Fluxbox only / sadece Fluxbox
```

`install.sh` detects the session and the window manager. On Fluxbox it delegates to the proven
`setup-fluxbox.sh`; elsewhere it installs to `~/.alttab-linux`, frees Alt+Tab where that can be done
from the command line (XFCE, MATE, Cinnamon, GNOME), writes
`~/.config/autostart/alttab-personal.desktop`, checks and repairs the Alt→Mod1 mapping, then verifies
the install. KDE, i3, sway and unknown window managers need the shortcut cleared by hand — the script
prints exactly where.

`install.sh` oturumu ve pencere yoneticisini tespit eder. Fluxbox'ta kanitlanmis `setup-fluxbox.sh`'e
devreder; diger masaustlerinde `~/.alttab-linux` icine kurar, Alt+Tab'i komut satirindan serbest
birakabildigi yerlerde birakir (XFCE, MATE, Cinnamon, GNOME), `~/.config/autostart/` kaydini yazar,
Alt→Mod1 eslesmesini kontrol edip onarir ve kurulumu dogrular. KDE, i3, sway ve bilinmeyen pencere
yoneticilerinde kisayol elle temizlenmelidir — betik nerede oldugunu yazar.

`~/.fluxbox/keys` icindeki `Mod1 Tab` baglamasi yedeklenerek serbest birakilir, bu klasor
`~/.alttab-linux` icine kopyalanir, Alt tusunun gercekten Mod1 urettigi kontrol edilir ve degilse
modifier haritasi duzeltilir (ayni korumali onarim `~/.fluxbox/startup` dosyasina yazilir), otomatik
baslatma kurulur ve uygulama baslatilir.

## 2. Check an installation / Kurulumu dogrula

```bash
bash check-install.sh
```

Reports: is Alt on Mod1, is `~/.alttab-linux` the same as this source, is the app running, are the
autostart and repair blocks in `~/.fluxbox/startup`, the log tail, who currently owns `Mod1+Tab`, and
any `xmodmap` line that could break the map.

## 3. Start and stop by hand / Elle baslat ve durdur

```bash
pkill -f alttab_personal.py                                   # stop / durdur
~/.alttab-linux/run.sh --debug >> ~/.alttab-linux/alttab.log 2>&1 &   # start / baslat
tail -30 ~/.alttab-linux/alttab.log                           # log
```

## 4. When Alt+Tab stops working / Alt+Tab calismadiginda

```bash
xmodmap -pm | grep -E "^mod1|^control"      # is Alt still Mod1? / Alt hala Mod1 mi
```

If `mod1` is empty and `Alt_L` sits under `control`, nothing bound to Mod1 can ever fire (this
switcher and Fluxbox's own `NextWindow` alike). Repair it:

```bash
xmodmap -e "clear control" -e "add control = Control_L Control_R" \
        -e "clear mod1"    -e "add mod1 = Alt_L"
```

`mod1` bosse ve `Alt_L` `control` altindaysa, Mod1'e bagli hicbir sey tetiklenemez (bu degistirici ve
Fluxbox'in kendi `NextWindow`'u dahil). Yukaridaki komutla duzelt.

To find what breaks it at login / girişte bunu neyin bozduğunu bulmak icin:

```bash
grep -n xmodmap ~/.fluxbox/startup ~/.profile ~/.xinitrc ~/.config/autostart/*.desktop 2>/dev/null
```

## 5. Run it from a shell without a display / Ekransiz kabuktan calistirma

The app guesses `:0` when `DISPLAY` is unset, and over SSH you can be explicit:

```bash
DISPLAY=:0 XAUTHORITY="$HOME/.Xauthority" ~/.alttab-linux/run.sh &
```

## 6. Tests / Testler

```bash
python3 tests/test_logic.py          # pure logic / saf mantik
python3 tests/test_hotkey_logic.py   # event routing with fake events / sahte olaylarla yonlendirme
python3 tests/test_imports.py        # import smoke test / import duman testi
DISPLAY=:0 python3 tests/test_live_display.py   # real X display / gercek ekran (app stopped / durdurulmus)
python3 -m doctest logic.py          # doctests
```
