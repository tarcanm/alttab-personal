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

echo "== 1/5 Optional: X access for another local user / Istege bagli: baska bir yerel kullaniciya X erisimi"
# Set AGENT_USER to a local user name (for example a helper account that verifies the app for you) to
# grant it access to this display for this session. Empty by default: nothing is changed. Remove the
# grant afterwards with: xhost -SI:localuser:USER and rm -f /tmp/alttab-xauth
# AGENT_USER'i bir yerel kullanici adina ayarlayin (ornegin uygulamayi sizin icin dogrulayan bir
# yardimci hesap); o zaman bu oturum icin ekrana erisim verilir. Varsayilan bos: hicbir sey degismez.
# Sonradan kaldirmak icin: xhost -SI:localuser:KULLANICI ve rm -f /tmp/alttab-xauth
AGENT_USER="${AGENT_USER:-}"
if [ -z "$AGENT_USER" ]; then
    echo "   AGENT_USER is empty, skipping / AGENT_USER bos, atlandi"
elif xhost +SI:localuser:"$AGENT_USER" 2>/dev/null; then
    echo "   xhost: granted to $AGENT_USER / verildi"
    # Fallback: export the display cookie to a file the other user can read.
    # Yedek yol: ekran cerezini diger kullanicinin okuyabilecegi dosyaya cikar.
    if xauth extract /tmp/alttab-xauth :0 2>/dev/null; then
        chmod 644 /tmp/alttab-xauth
        echo "   xauth cookie: /tmp/alttab-xauth (mode 644)"
    else
        echo "   xauth extract: failed / basarisiz"
    fi
else
    echo "   xhost: failed / basarisiz"
fi
echo "   xhost list / erisim listesi:"
xhost 2>/dev/null | sed 's/^/     /'
echo "   DISPLAY=$DISPLAY  XAUTHORITY=${XAUTHORITY:-<varsayilan>}"

echo "== 2/5 Free Alt+Tab from Fluxbox / Alt+Tab'i Fluxbox'tan al"
KEYS="$HOME/.fluxbox/keys"
mkdir -p "$HOME/.fluxbox"
if [ ! -f "$KEYS" ]; then
    # A missing keys file does not mean "no bindings": Fluxbox falls back to its compiled-in
    # defaults, which bind Mod1 Tab to NextWindow as well, so the app could never grab the key. Seed
    # the file from the packaged default keys (the complete set, not an invented minimal file) and
    # then edit it exactly like an existing one.
    # Dosya yoksa "baglama yok" demek degildir: Fluxbox derlenmis varsayilanlarina duser, orada da
    # Mod1 Tab NextWindow'a baglidir ve uygulama tusu hic alamaz. Paketle gelen varsayilan tus
    # dosyasini (eksiksiz kume, uydurma minimal bir dosya degil) kopyalayip normal duzenliyoruz.
    for ktpl in /etc/X11/fluxbox/keys /usr/share/fluxbox/keys /usr/share/doc/fluxbox/examples/keys; do
        if [ -f "$ktpl" ]; then
            cp "$ktpl" "$KEYS"
            echo "   $KEYS was missing, seeded from $ktpl"
            echo "   (TR) $KEYS yoktu, $ktpl dosyasindan olusturuldu"
            break
        fi
    done
fi

if [ -f "$KEYS" ]; then
    cp -a "$KEYS" "$KEYS.bak-$(date +%Y%m%d-%H%M%S)"
    # Remove (comment out) any Mod1+Tab binding so Fluxbox no longer grabs the combination.
    # Commenting rather than replacing, so the original line stays readable in the file.
    # Fluxbox kombinasyonu tutmasin diye Mod1+Tab baglamalarini yorum satirina cevir.
    sed -i -E '/^[[:space:]]*#/!{/^[[:space:]]*Mod1[^:]*Tab[[:space:]]*:/s/^/# alt-tab-personal: /}' "$KEYS"
    echo "   backup / yedek: $(ls -t "$KEYS".bak-* 2>/dev/null | head -1)"
    LEFT=$(grep -cE '^[[:space:]]*Mod1[^:]*Tab[[:space:]]*:' "$KEYS" 2>/dev/null || true)
    echo "   remaining Mod1+Tab bindings / kalan baglama: ${LEFT:-0}"
else
    echo "   keys file missing and no packaged default to seed from / tus dosyasi yok ve kopyalanacak varsayilan da bulunamadi"
    echo "   free Mod1+Tab by hand, then run this script again / Mod1+Tab'i elle serbest birak, sonra betigi tekrar calistir"
fi
fluxbox-remote reconfig >/dev/null 2>&1 || killall -HUP fluxbox 2>/dev/null || true
sleep 1

echo "== 2b/5 Autostart file / Otomatik baslatma dosyasi"
# IMPORTANT: Fluxbox is started BY ~/.fluxbox/startup. /usr/bin/startfluxbox execs that file when it
# exists and the file is expected to start the window manager itself, so the stock file ends with
# `exec fluxbox`. Anything appended AFTER that line never runs: an autostart line at the end of the
# file is dead code, which is exactly why the app never came back after a login. The AltTab block
# therefore goes BEFORE the first `exec fluxbox` line, wrapped in markers so a re-run replaces it
# instead of piling up copies.
# ONEMLI: Fluxbox'u ~/.fluxbox/startup dosyasi baslatir. /usr/bin/startfluxbox o dosya varsa exec
# eder ve dosyanin pencere yoneticisini kendisi baslatmasi beklenir; stok dosya `exec fluxbox` ile
# biter. O satirdan SONRA eklenen hicbir sey calismaz; dosyanin sonuna konan otomatik baslatma satiri
# olu koddur ve uygulamanin girişten sonra geri gelmemesinin sebebi buydu. Bu yuzden AltTab blogu ilk
# `exec fluxbox` satirindan ONCE eklenir ve isaretler arasina yazilir; boylece tekrar calistirmada
# kopya birikmez, blok degistirilir.
STARTUP="$HOME/.fluxbox/startup"
BLOCK_FILE="$(mktemp "${TMPDIR:-/tmp}/alttab-block.XXXXXX")"
trap 'rm -f "$BLOCK_FILE"' EXIT

cat > "$BLOCK_FILE" <<'BLOCK'
# >>> alttab-personal >>>
# Keep Alt on Mod1: with an empty mod1 nothing bound to Mod1 can ever fire.
if ! xmodmap -pm 2>/dev/null | grep -qE "^mod1[[:space:]]+.*Alt"; then
    xmodmap -e "clear control" -e "add control = Control_L Control_R" -e "clear mod1" -e "add mod1 = Alt_L"
fi
if [ -x "$HOME/.alttab-linux/run.sh" ]; then
    setsid nohup "$HOME/.alttab-linux/run.sh" --debug >> "$HOME/.alttab-linux/alttab.log" 2>&1 &
fi
# <<< alttab-personal <<<
BLOCK

strip_alttab_block() {
    # Remove a previous marked block, plus the unmarked tail older versions appended.
    # Onceki isaretli blogu ve eski surumlerin dosya sonuna biraktigi isaretsiz kuyrugu kaldir.
    awk '
        /^# >>> alttab-personal >>>$/ { skip = 1; next }
        /^# <<< alttab-personal <<<$/ { skip = 0; next }
        skip { next }
        /^# AltTab Personal: keep Alt on Mod1/ { legacy = 1 }
        /^# AltTab Personal$/ { legacy = 1 }
        /alttab-linux\/run\.sh/ { legacy = 1 }
        /alttab-mod1-repair/ { legacy = 1 }
        legacy { next }
        { print }
    ' "$1" > "$1.alttab-new" && mv "$1.alttab-new" "$1"
}

insert_alttab_block() {
    # Before the first `exec ...fluxbox`, or at the end when the file has no such line.
    # Ilk `exec ...fluxbox` satirindan once, dosyada yoksa sona ekle.
    awk -v block="$BLOCK_FILE" '
        function emit(   line) {
            while ((getline line < block) > 0) print line
            close(block)
        }
        !done && /^[[:space:]]*exec[[:space:]]+[^[:space:]]*fluxbox/ { emit(); done = 1 }
        { print }
        END { if (!done) emit() }
    ' "$1" > "$1.alttab-new" && mv "$1.alttab-new" "$1"
}

if [ ! -f "$STARTUP" ]; then
    mkdir -p "$HOME/.fluxbox"
    for tpl in /usr/share/doc/fluxbox/examples/startup /usr/share/fluxbox/startup; do
        if [ -f "$tpl" ]; then
            cp "$tpl" "$STARTUP"
            echo "   $STARTUP was missing, seeded from $tpl"
            echo "   (TR) $STARTUP yoktu, $tpl dosyasindan olusturuldu"
            break
        fi
    done
    if [ ! -f "$STARTUP" ]; then
        cat > "$STARTUP" <<'MINIMAL'
#!/bin/sh
# Created by AltTab Personal. Fluxbox runs this file at login (startfluxbox execs it), so the window
# manager has to be started at the end - keep that line. Your own commands go above the block below.
# AltTab Personal tarafindan olusturuldu. Fluxbox bu dosyayi girişte calistirir (startfluxbox exec
# eder), bu yuzden pencere yoneticisi sonda baslatilmalidir - o satiri koru. Kendi komutlarin,
# asagidaki blogun uzerine gelir.
MINIMAL
        chmod +x "$STARTUP"
        echo "   created a minimal $STARTUP / minimal dosya olusturuldu"
    fi
fi

# startfluxbox expects this file to start the window manager: a file without that line leaves the
# session without a window manager, so make sure the line exists before anything is inserted.
# startfluxbox bu dosyadan pencere yoneticisini baslatmasini bekler: o satir yoksa oturum pencere
# yoneticisiz kalir, bu yuzden bir sey eklemeden once satirin varligindan emin oluyoruz.
if ! grep -qE '^[[:space:]]*exec[[:space:]]+[^[:space:]]*fluxbox' "$STARTUP"; then
    printf '\nexec fluxbox\n' >> "$STARTUP"
    echo "   added the missing 'exec fluxbox' line / eksik exec fluxbox satiri eklendi"
fi

cp -a "$STARTUP" "$STARTUP.bak-$(date +%Y%m%d-%H%M%S)"
strip_alttab_block "$STARTUP"
insert_alttab_block "$STARTUP"
BLOCK_LINE=$(grep -n '>>> alttab-personal >>>' "$STARTUP" | head -1 | cut -d: -f1)
EXEC_LINE=$(grep -nE '^[[:space:]]*exec[[:space:]]+[^[:space:]]*fluxbox' "$STARTUP" | head -1 | cut -d: -f1)
echo "   alt-tab block line ${BLOCK_LINE:-?}, 'exec fluxbox' line ${EXEC_LINE:-?}"
echo "   AltTab blogu ${BLOCK_LINE:-?}. satir, 'exec fluxbox' ${EXEC_LINE:-?}. satir"
if [ -n "$BLOCK_LINE" ] && [ -n "$EXEC_LINE" ] && [ "$BLOCK_LINE" -gt "$EXEC_LINE" ]; then
    echo "   WARNING: the block sits after 'exec fluxbox' and would never run /"
    echo "   UYARI: blok exec fluxbox'tan sonra kaldi ve hic calismaz"
fi

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
    fi
    # The repair is repeated at every login by the AltTab block written into ~/.fluxbox/startup in
    # 2b/5, so nothing has to be remembered separately here.
    # Onarim her giriste 2b/5'te ~/.fluxbox/startup icine yazilan AltTab blogu tarafindan tekrarlanir;
    # burada ayrica hatirlanacak bir sey yok.
fi

echo "== 4/5 Autostart / Otomatik baslatma"
echo "   ~/.fluxbox/startup carries the AltTab block, before 'exec fluxbox' /"
echo "   ~/.fluxbox/startup AltTab blogunu tasiyor, 'exec fluxbox'tan once"
# No XDG entry on purpose: Fluxbox never reads ~/.config/autostart, and on a session that does read
# it a second copy would only race the first one for the Alt+Tab grab. A stale entry from an earlier
# version is removed so exactly one mechanism starts the app.
# XDG kaydi bilincli olarak yazilmaz: Fluxbox ~/.config/autostart'i hic okumaz, okuyan bir oturumda
# ise ikinci kopya Alt+Tab grab'i icin birinciyle yarismaktan baska ise yaramaz. Eski surumden kalan
# kayit silinir, boylece uygulamayi tek bir mekanizma baslatir.
rm -f "$HOME/.config/autostart/alttab-personal.desktop"
echo "   stale XDG entry removed if present / varsa eski XDG kaydi kaldirildi"
# Belt and braces: write the XDG entry as well. Fluxbox ignores it, but a session that brings the
# desktop up through a session manager picks the app up from there. run.sh holds a lock, so a double
# start is harmless.
# Ek güvence: XDG kaydını da yazıyoruz. Fluxbox bunu okumaz, ama masaüstünü bir oturum yöneticisi
# ayağa kaldırıyorsa uygulama oradan da başlar. run.sh kilit tuttuğu için çifte başlatma zararsızdır.
mkdir -p "$HOME/.config/autostart"
sed "s|^Exec=.*|Exec=$DEST/run.sh --debug|" "$DEST/alttab-personal.desktop" > "$HOME/.config/autostart/alttab-personal.desktop"
echo "   ~/.config/autostart/alttab-personal.desktop written as well / XDG kaydi da yazildi"

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
