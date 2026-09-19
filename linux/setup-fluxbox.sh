#!/usr/bin/env bash
# AltTab Personal (Linux) - one-time setup for a Fluxbox/X11 desktop.
# AltTab Personal (Linux) - Fluxbox/X11 masaustu icin tek seferlik kurulum.
#
# Run it as your desktop user, inside the graphical session, not as root:
#   bash setup-fluxbox.sh
# Masaustu kullanicin olarak, grafik oturumunun icinde calistir, root olarak degil.
#
# What it does / Ne yapar:
#   1. grants the Hermes user temporary X access, so Hermes can verify the app live
#      / Hermes kullanicisina gecici X erisimi verir, boylece Hermes uygulamayi canli dogrulayabilir
#   2. comments out Fluxbox's Mod1+Tab bindings (with a backup) and reloads the window manager
#      / Fluxbox'un Mod1+Tab baglamalarini yorum satirina cevirir (yedekli) ve WM'i yeniler
#   3. installs the app into ~/.alttab-linux and runs the offline tests
#      / uygulamayi ~/.alttab-linux icine kurar ve cevrimdisi testleri kosar
#   4. installs autostart (fluxbox startup or ~/.config/autostart)
#      / otomatik baslatmayi kurar
#   5. starts the switcher and prints its log
#      / degistiriciyi baslatir ve gunlugunu yazar
set -u

SRC="${SRC:-$(cd "$(dirname "$0")" && pwd)}"
DEST="$HOME/.alttab-linux"

echo "== 1/5 X access for Hermes (this session only) / Hermes icin X erisimi (sadece bu oturum)"
xhost +SI:localuser:hermes-host || echo "   xhost failed / basarisiz"

echo "== 2/5 Free Alt+Tab from Fluxbox / Alt+Tab'i Fluxbox'tan al"
KEYS="$HOME/.fluxbox/keys"
mkdir -p "$HOME/.fluxbox"
if [ -f "$KEYS" ]; then
    cp -a "$KEYS" "$KEYS.bak-$(date +%Y%m%d-%H%M%S)"
else
    : > "$KEYS"
fi
sed -i -E 's|^([[:space:]]*)(Mod1[[:space:]]+Tab[[:space:]]*:)|# alt-tab-personal: \1\2|' "$KEYS"
if ! grep -qE '^Mod1[[:space:]]+Tab[[:space:]]*:' "$KEYS"; then
    {
        echo ""
        echo "# AltTab Personal owns Alt+Tab / Alt+Tab artik AltTab Personal'a ait"
        echo "Mod1 Tab :ExecCommand /bin/true"
        echo "Mod1 Shift Tab :ExecCommand /bin/true"
    } >> "$KEYS"
fi
echo "   backup / yedek: $(ls -t "$KEYS".bak-* 2>/dev/null | head -1)"
fluxbox-remote reconfig >/dev/null 2>&1 || killall -HUP fluxbox 2>/dev/null || true
sleep 1

echo "== 3/5 Install to ~/.alttab-linux / ~/.alttab-linux icine kur"
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$SRC"/. "$DEST"/
rm -rf "$DEST/__pycache__" "$DEST/tests/__pycache__"
chmod +x "$DEST/run.sh" "$DEST/setup-fluxbox.sh"
( cd "$DEST" && python3 tests/test_logic.py 2>&1 | tail -3 )
echo "   smoke test / duman testi:"
( cd "$DEST" && python3 alttab_personal.py --print-windows 2>&1 | head -12 )

echo "== 4/5 Autostart / Otomatik baslatma"
if [ -f "$HOME/.fluxbox/startup" ]; then
    if ! grep -q 'alttab-linux' "$HOME/.fluxbox/startup"; then
        printf '\n# AltTab Personal\n[ -x "$HOME/.alttab-linux/run.sh" ] && "$HOME/.alttab-linux/run.sh" &\n' >> "$HOME/.fluxbox/startup"
    fi
    echo "   ~/.fluxbox/startup updated / guncellendi"
else
    mkdir -p "$HOME/.config/autostart"
    sed "s|^Exec=.*|Exec=$DEST/run.sh|" "$DEST/alttab-personal.desktop" > "$HOME/.config/autostart/alttab-personal.desktop"
    echo "   ~/.config/autostart/alttab-personal.desktop written / yazildi"
fi

echo "== 5/5 Start / Baslat"
pkill -f 'alttab_personal.py' 2>/dev/null
sleep 0.3
setsid nohup "$DEST/run.sh" --debug > "$DEST/alttab.log" 2>&1 &
sleep 2
if pgrep -f 'alttab_personal.py' >/dev/null 2>&1; then
    echo "   running / calisiyor (log: ~/.alttab-linux/alttab.log)"
    tail -3 "$DEST/alttab.log"
else
    echo "   NOT RUNNING / BASLAMADI - log:"
    tail -10 "$DEST/alttab.log"
fi
echo ""
echo "Test: hold Alt, press Tab. / Test: Alt basili tut, Tab'a bas."
echo "Paste this output back to Hermes. / Bu ciktiyi Hermes'e yapistir."
