#!/usr/bin/env bash
# AltTab Personal (Linux) installation check / kurulum dogrulamasi.
# Run it as the desktop user, inside the graphical session, whenever you want to know whether the
# switcher is installed correctly and whether Alt+Tab can work at all.
# Masaustu kullanicisi olarak, grafik oturumunun icinde calistir; degistiricinin dogru kurulu olup
# olmadigini ve Alt+Tab'in calisip calisamayacagini soyler.
set -u

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${DEST:-$HOME/.alttab-linux}"
STARTUP="$HOME/.fluxbox/startup"

echo "=========== AltTab check / kontrol ==========="

echo "== 1) Modifier map: Alt must be Mod1 / Alt Mod1 olmali"
if command -v xmodmap >/dev/null 2>&1; then
    xmodmap -pm 2>/dev/null | grep -E "^mod1|^control|^mod5" || echo "   (could not read / okunamadi)"
    if xmodmap -pm 2>/dev/null | grep -qE '^mod1[[:space:]]+.*Alt'; then
        echo "   OK: mod1 contains Alt / mod1 Alt iceriyor"
    else
        echo "   BROKEN: Alt is not Mod1, Alt+Tab can never fire / Alt Mod1 degil, Alt+Tab tetiklenemez"
        echo "   fix / duzelt: xmodmap -e \"clear control\" -e \"add control = Control_L Control_R\" \\"
        echo "                        -e \"clear mod1\" -e \"add mod1 = Alt_L\""
    fi
else
    echo "   xmodmap is missing, install x11-xserver-utils / xmodmap yok"
fi

echo "== 2) Installed copy vs source / kurulu kopya ile kaynak ayni mi"
if [ -f "$DEST/x11_hotkey.py" ]; then
    # Compare every file that can change behaviour, not just two: a stale x11_hotkey.py or run.sh is
    # enough for "the fix is in the repo but not on this machine".
    # Davranisi degistirebilecek tum dosyalari karsilastir: eski bir x11_hotkey.py ya da run.sh,
    # "duzeltme repoda var ama makinede yok" demek icin yeterlidir.
    STALE=0
    for f in x11_hotkey.py alttab_personal.py window_list.py panel.py logic.py l.py run.sh; do
        if [ ! -f "$DEST/$f" ]; then
            echo "   MISSING: $f"
            STALE=1
        elif [ "$(md5sum < "$DEST/$f")" != "$(md5sum < "$SRC/$f")" ]; then
            echo "   STALE: $f"
            STALE=1
        fi
    done
    if [ "$STALE" = "0" ]; then
        echo "   OK: installed copy matches this source / kurulu kopya bu kaynakla ayni"
    else
        echo "   re-run install.sh to refresh / tazelemek icin install.sh tekrar calistir"
    fi
else
    echo "   $DEST does not exist yet / henuz yok: run setup-fluxbox.sh"
fi

echo "== 3) Running process / calisan surec"
pgrep -af "alttab_personal.py" | head -3 || echo "   (not running / calismiyor)"

echo "== 4) Autostart file / otomatik baslatma dosyasi"
# /usr/bin/startfluxbox execs this file and the file is expected to start the window manager, so the
# stock file ends with `exec fluxbox`. A block placed after that line never runs, which is the classic
# reason for "works after installing, dead after the next login".
# /usr/bin/startfluxbox bu dosyayi exec eder ve dosya pencere yoneticisini baslatmalidir; stok dosya
# `exec fluxbox` ile biter. O satirdan sonra duran blok hic calismaz; "kurulumdan sonra calisiyor,
# sonraki giristen sonra olu" durumunun klasik sebebi budur.
if [ -f "$STARTUP" ]; then
    echo "   shebang/izin : $(head -1 "$STARTUP")  $([ -x "$STARTUP" ] && echo '(executable)' || echo '(not executable; startfluxbox runs it with sh)')"
    EXEC_LN=$(grep -nE '^[[:space:]]*exec[[:space:]]+[^[:space:]]*fluxbox' "$STARTUP" | head -1 | cut -d: -f1)
    BLK_LN=$(grep -n '>>> alttab-personal >>>' "$STARTUP" | head -1 | cut -d: -f1)
    echo "   exec fluxbox : ${EXEC_LN:-MISSING}    alt-tab block: ${BLK_LN:-MISSING}"
    if [ -z "${EXEC_LN:-}" ]; then
        echo "   BROKEN: no line starts the window manager, the session would have no WM /"
        echo "   BOZUK: pencere yoneticisini baslatan satir yok, oturumda WM olmaz"
    elif [ -z "${BLK_LN:-}" ]; then
        echo "   MISSING: no alt-tab block / AltTab blogu yok"
    elif [ "$BLK_LN" -gt "$EXEC_LN" ]; then
        echo "   BROKEN: the block sits after 'exec fluxbox', it never runs at login /"
        echo "   BOZUK: blok 'exec fluxbox'tan sonra, giriste hic calismaz"
    else
        echo "   OK: the block runs before the window manager starts / blok WM'den once calisir"
    fi
    grep -n -A4 '>>> alttab-personal >>>' "$STARTUP" 2>/dev/null | head -12
else
    echo "   (no $STARTUP / dosya yok)"
fi

echo "== 5) Application log, last 8 lines / uygulama gunlugu"
tail -8 "$DEST/alttab.log" 2>/dev/null || echo "   (no log yet / gunluk yok)"

echo "== 6) Who owns Mod1+Tab / Mod1+Tab kimin elinde"
if [ -n "${DISPLAY:-}" ]; then
    python3 - <<'PY' 2>&1 | head -6
try:
    from Xlib import X, XK, display

    connection = display.Display()
    root = connection.screen().root
    errors = []
    connection.set_error_handler(lambda error, request: errors.append(error))
    tab = connection.keysym_to_keycode(XK.string_to_keysym("Tab"))
    root.grab_key(tab, X.Mod1Mask, True, X.GrabModeAsync, X.GrabModeAsync)
    connection.sync()
    if errors:
        print("   Mod1+Tab is held by another client (the app, or the window manager) / baska bir istemci tutuyor (uygulama ya da pencere yoneticisi)")
    else:
        print("   Mod1+Tab is FREE: nothing holds it, so Alt+Tab cannot work / serbest: Alt+Tab calismaz")
        root.ungrab_key(tab, X.Mod1Mask)
        connection.sync()
    connection.close()
except Exception as exc:
    print("   could not check / kontrol edilemedi:", exc)
PY
else
    echo "   DISPLAY is not set, run this inside the graphical session / DISPLAY yok"
fi

echo "== 7) Anything that breaks the modifier map / haritayi bozan satir"
grep -n xmodmap "$STARTUP" "$HOME/.profile" "$HOME/.xinitrc" 2>/dev/null | head -10 || true

echo "=========== done / bitti ==========="
