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
    md5sum "$DEST/x11_hotkey.py" "$SRC/x11_hotkey.py" 2>&1
    md5sum "$DEST/alttab_personal.py" "$SRC/alttab_personal.py" 2>&1
    if [ "$(md5sum < "$DEST/x11_hotkey.py")" = "$(md5sum < "$SRC/x11_hotkey.py")" ]; then
        echo "   OK: installed copy matches this source / kurulu kopya bu kaynakla ayni"
    else
        echo "   STALE: re-run setup-fluxbox.sh / eski surum, setup-fluxbox.sh tekrar calistir"
    fi
else
    echo "   $DEST does not exist yet / henuz yok: run setup-fluxbox.sh"
fi

echo "== 3) Running process / calisan surec"
pgrep -af "alttab_personal.py" | head -3 || echo "   (not running / calismiyor)"

echo "== 4) Autostart and repair blocks in $STARTUP"
if [ -f "$STARTUP" ]; then
    grep -n -B1 -A5 "AltTab Personal\|alttab-mod1-repair\|alttab-linux" "$STARTUP" 2>/dev/null | head -30 \
        || echo "   (no AltTab block found / blok yok)"
else
    echo "   (no $STARTUP, the app was installed for ~/.config/autostart instead)"
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
        print("   Mod1+Tab is held by a client (the app when it runs) / bir istemci tutuyor (uygulama)")
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
