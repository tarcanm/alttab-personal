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
START_APP=0
for arg in "$@"; do
    [ "$arg" = "--start" ] && START_APP=1
done

echo "== 1/5 X access for Hermes (this session only) / Hermes icin X erisimi (sadece bu oturum)"
if xhost +SI:localuser:hermes-host 2>/dev/null; then
    echo "   xhost: granted / verildi"
else
    echo "   xhost: failed / basarisiz"
fi
# Fallback: export the display cookie to a temp file. Hermes uses it as XAUTHORITY.
# Delete it when the test is over: rm /tmp/alttab-xauth
# Yedek yol: ekran cerezini gecici dosyaya cikar. Hermes bunu XAUTHORITY olarak kullanir.
# Test bitince sil: rm /tmp/alttab-xauth
if xauth extract /tmp/alttab-xauth :0 2>/dev/null; then
    chmod 644 /tmp/alttab-xauth
    echo "   xauth cookie: /tmp/alttab-xauth (mode 644)"
else
    echo "   xauth extract: failed / basarisiz"
fi
echo "   xhost list / erisim listesi:"
xhost 2>/dev/null | sed 's/^/     /'
echo "   DISPLAY=$DISPLAY  XAUTHORITY=${XAUTHORITY:-<varsayilan>}"

echo "== 2/5 Free Alt+Tab from Fluxbox / Alt+Tab'i Fluxbox'tan al"
KEYS="$HOME/.fluxbox/keys"
mkdir -p "$HOME/.fluxbox"
if [ ! -f "$KEYS" ]; then
    # Do NOT invent a minimal keys file: that would drop every compiled-in default binding
    # (Alt+F1 root menu, workspace keys, ...). We only edit it when it exists.
    # Minimal bir keys dosyasi UYDURMUYORUZ: o zaman Fluxbox'un derlenmis varsayilan baglamalari
    # (Alt+F1 menu, calisma alani tuslari...) kaybolur. Sadece var olan dosyayi duzenliyoruz.
    echo "   ~/.fluxbox/keys not found / yok. Fluxbox compiled defaults are in use;"
    echo "   skipping the key edit. If the app cannot grab Alt+Tab, start Fluxbox once so it"
    echo "   writes ~/.fluxbox/keys, then run this script again."
    echo "   (Turkce) keys dosyasi yok, tus duzenlemesi atlandi; uygulama Alt+Tab'i alamazsa"
    echo "   Fluxbox'u bir kez baslatip dosyanin olusmasini sagla, sonra betigi tekrar calistir."
else
    cp -a "$KEYS" "$KEYS.bak-$(date +%Y%m%d-%H%M%S)"
    # Remove (comment out) any Mod1+Tab binding so Fluxbox no longer grabs the combination.
    # Commenting rather than replacing, so the original line stays readable in the file.
    # Fluxbox kombinasyonu tutmasin diye Mod1+Tab baglamalarini yorum satirina cevir.
    sed -i -E '/^[[:space:]]*#/!{/^[[:space:]]*Mod1[^:]*Tab[[:space:]]*:/s/^/# alt-tab-personal: /}' "$KEYS"
    echo "   backup / yedek: $(ls -t "$KEYS".bak-* 2>/dev/null | head -1)"
    LEFT=$(grep -cE '^[[:space:]]*Mod1[^:]*Tab[[:space:]]*:' "$KEYS" 2>/dev/null || true)
    echo "   remaining Mod1+Tab bindings / kalan baglama: ${LEFT:-0}"
fi
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

echo "== 3b/5 Alt modifier check / Alt modifier kontrolu"
# Alt must be Mod1. With an empty mod1 nothing bound to Mod1 ever fires: neither our Alt+Tab grab
# nor Fluxbox's own NextWindow. Some sessions come up with Alt_L sitting inside "control" instead,
# which looks healthy but makes Alt+Tab impossible.
# Alt Mod1 olmalidir. mod1 bosken Mod1'e bagli hicbir sey tetiklenmez: ne bizim Alt+Tab grab'imiz ne
# Fluxbox'in kendi NextWindow'u. Bazi oturumlar Alt_L'yi "control" icine koyar; saglikli gorunur ama
# Alt+Tab imkansiz olur.
if command -v xmodmap >/dev/null 2>&1; then
    if xmodmap -pm 2>/dev/null | grep -qE '^mod1[[:space:]]+.*Alt'; then
        echo "   mod1 already contains Alt / mod1 zaten Alt iceriyor"
    else
        xmodmap -e "clear control" -e "add control = Control_L Control_R" \
                 -e "clear mod1" -e "add mod1 = Alt_L" 2>/dev/null || true
        if xmodmap -pm 2>/dev/null | grep -qE '^mod1[[:space:]]+.*Alt'; then
            echo "   mod1 repaired for this session / bu oturum icin duzeltildi"
        else
            echo "   WARNING: could not repair mod1 / mod1 duzeltilemedi"
        fi
        # Remember the repair for the next login / Onarimi sonraki giris icin hatirla
        if [ -f "$HOME/.fluxbox/startup" ] && ! grep -q 'alttab-mod1-repair' "$HOME/.fluxbox/startup"; then
            printf '\n# AltTab Personal: keep Alt on Mod1 / Alt Mod1 de kalsin\n# alttab-mod1-repair\nif ! xmodmap -pm 2>/dev/null | grep -qE "^mod1[[:space:]]+.*Alt"; then\n    xmodmap -e "clear control" -e "add control = Control_L Control_R" -e "clear mod1" -e "add mod1 = Alt_L"\nfi\n' >> "$HOME/.fluxbox/startup"
            echo "   repair added to ~/.fluxbox/startup / onarim startup dosyasina eklendi"
        fi
    fi
fi

echo "== 4/5 Autostart / Otomatik baslatma"
if [ -f "$HOME/.fluxbox/startup" ]; then
    if grep -q '\[ -x "$HOME/.alttab-linux/run.sh" \]' "$HOME/.fluxbox/startup"; then
        # Replace the old one-liner with a logging version, so a failed start at login is
        # diagnosable instead of silent / Eski tek satiri gunluk yazan surumle degistir; boylece
        # giriste basarisiz bir baslatma sessiz kalmaz, incelenebilir.
        sed -i '\|\[ -x "$HOME/.alttab-linux/run.sh" \]|d' "$HOME/.fluxbox/startup"
        printf 'if [ -x "$HOME/.alttab-linux/run.sh" ]; then\n    "$HOME/.alttab-linux/run.sh" --debug >> "$HOME/.alttab-linux/alttab.log" 2>&1 &\nfi\n' >> "$HOME/.fluxbox/startup"
        echo "   autostart line upgraded to log to ~/.alttab-linux/alttab.log"
    elif ! grep -q 'alttab-linux' "$HOME/.fluxbox/startup"; then
        printf '\n# AltTab Personal\nif [ -x "$HOME/.alttab-linux/run.sh" ]; then\n    "$HOME/.alttab-linux/run.sh" --debug >> "$HOME/.alttab-linux/alttab.log" 2>&1 &\nfi\n' >> "$HOME/.fluxbox/startup"
    fi
    echo "   ~/.fluxbox/startup updated / guncellendi"
else
    mkdir -p "$HOME/.config/autostart"
    sed "s|^Exec=.*|Exec=$DEST/run.sh|" "$DEST/alttab-personal.desktop" > "$HOME/.config/autostart/alttab-personal.desktop"
    echo "   ~/.config/autostart/alttab-personal.desktop written / yazildi"
fi

echo "== 5/5 Start / Baslat"
if [ "$START_APP" = "1" ]; then
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
else
    echo "   app NOT started yet (Hermes runs the live test first) /"
    echo "   uygulama henuz baslatilmadi (once Hermes canli testi yapacak)"
fi
echo ""
echo "Paste this output back to Hermes. / Bu ciktiyi Hermes'e yapistir."
echo "Later, start it yourself with: / Sonra kendin baslat:"
echo "  $DEST/run.sh &        # or re-run this script with --start / ya da bu betigi --start ile calistir"
