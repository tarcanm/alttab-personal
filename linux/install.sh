#!/usr/bin/env bash
# AltTab Personal (Linux) - desktop-aware installer for X11 sessions.
# AltTab Personal (Linux) - X11 oturumlari icin masaustunu taniyan kurulum.
#
# Run it as your desktop user, inside the graphical session, not as root:
#   bash install.sh              install / update
#   bash install.sh --start      install and start it now
#   bash install.sh --check      report only, change nothing
# Masaustu kullanicin olarak, grafik oturumun icinde calistir, root olarak degil:
#   bash install.sh              kur / guncelle
#   bash install.sh --start      kur ve hemen baslat
#   bash install.sh --check      sadece rapor, hicbir sey degistirmez
#
# What it does / Ne yapar:
#   1. detects the session (X11 vs Wayland) and the window manager
#      / oturumu (X11 mi Wayland mi) ve pencere yoneticisini tespit eder
#   2. Fluxbox: hands over to setup-fluxbox.sh, which is the proven path
#      / Fluxbox: kanitlanmis yol olan setup-fluxbox.sh'e devreder
#   3. other desktops: installs to ~/.alttab-linux, frees Alt+Tab where it can be done from the command
#      line, adds an XDG autostart entry, repairs the Alt/Mod1 mapping, verifies the install
#      / diger masaustleri: ~/.alttab-linux'a kurar, Alt+Tab'i komut satirindan serbest birakabildigi
#      yerlerde birakir, XDG otomatik baslatma kaydi ekler, Alt/Mod1 eslesmesini onarir, dogrular
set -u

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.alttab-linux"
MODE="install"
WM_OVERRIDE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --start) MODE="start"; shift ;;
        --check) MODE="check"; shift ;;
        --wm) WM_OVERRIDE="${2:-}"; shift 2 ;;
        --wm=*) WM_OVERRIDE="${1#--wm=}"; shift ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) shift ;;
    esac
done

say() { echo "$@"; }
# Prints the English line and, when given, the Turkish one.
# Tek argumanla cagrilirsa da guvenli olsun (set -u altinda $2 patlamasin).
en_tr() { echo "   $1"; if [ $# -gt 1 ]; then echo "   $2"; fi; }

# ---------------------------------------------------------------- environment
SESSION_TYPE="${XDG_SESSION_TYPE:-}"
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    SESSION_TYPE="wayland"
elif [ -z "$SESSION_TYPE" ] || [ "$SESSION_TYPE" = "tty" ] || [ "$SESSION_TYPE" = "unspecified" ]; then
    # Over SSH the session type is unreliable; a working DISPLAY means X11 in practice.
    # SSH uzerinden oturum tipi guvenilmez; calisan bir DISPLAY pratikte X11 demektir.
    if [ -n "${DISPLAY:-}" ]; then SESSION_TYPE="x11 (assumed, DISPLAY is set)"; else SESSION_TYPE="unknown"; fi
fi

detect_wm() {
    if [ -n "$WM_OVERRIDE" ]; then echo "$WM_OVERRIDE"; return; fi
    local id name
    if command -v xprop >/dev/null 2>&1; then
        id=$(xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | awk -F'# ' '{print $2}')
        if [ -n "${id:-}" ] && [ "$id" != "0x0" ]; then
            name=$(xprop -id "$id" _NET_WM_NAME 2>/dev/null | sed -n 's/.*= "\(.*\)"/\1/p')
            if [ -n "${name:-}" ]; then echo "$name" | tr '[:upper:]' '[:lower:]'; return; fi
        fi
    fi
    if command -v wmctrl >/dev/null 2>&1; then
        name=$(wmctrl -m 2>/dev/null | sed -n 's/^Name: //p')
        if [ -n "${name:-}" ]; then echo "$name" | tr '[:upper:]' '[:lower:]'; return; fi
    fi
    echo "${XDG_CURRENT_DESKTOP:-unknown}" | tr '[:upper:]' '[:lower:]'
}

WM="$(detect_wm)"
say "== AltTab Personal (Linux) - installer / kurulum =="
en_tr "session: ${SESSION_TYPE:-unknown}   desktop: ${XDG_CURRENT_DESKTOP:-unknown}   window manager: ${WM:-unknown}" \
      "oturum: ${SESSION_TYPE:-bilinmiyor}   masaustu: ${XDG_CURRENT_DESKTOP:-bilinmiyor}   pencere yoneticisi: ${WM:-bilinmiyor}"
en_tr "DISPLAY=${DISPLAY:-<empty>}  XAUTHORITY=${XAUTHORITY:-<default>}  user=$(id -un)" \
      "DISPLAY=${DISPLAY:-<bos>}  XAUTHORITY=${XAUTHORITY:-<varsayilan>}  kullanici=$(id -un)"

if [ "$MODE" = "check" ]; then
    say ""
    say "-- report / rapor --"
    en_tr "session type: $SESSION_TYPE  (the app needs X11; Wayland needs XWayland and may not see Alt+Tab)" \
          "oturum tipi: $SESSION_TYPE  (uygulama X11 ister; Wayland'da XWayland gerekir ve Alt+Tab'i gormeyebilir)"
    en_tr "window manager: ${WM:-unknown}" "pencere yoneticisi: ${WM:-bilinmiyor}"
    en_tr "installed copy: $([ -d "$DEST" ] && echo "$DEST (present)" || echo 'not installed')" \
          "kurulu kopya: $([ -d "$DEST" ] && echo "$DEST (var)" || echo 'kurulu degil')"
    en_tr "running: $(pgrep -f alttab_personal.py >/dev/null 2>&1 && echo yes || echo no)" \
          "calisiyor mu: $(pgrep -f alttab_personal.py >/dev/null 2>&1 && echo evet || echo hayir)"
    en_tr "autostart: $([ -f "$HOME/.config/autostart/alttab-personal.desktop" ] && echo "$HOME/.config/autostart/alttab-personal.desktop" || echo none)" \
          "otomatik baslatma: $([ -f "$HOME/.config/autostart/alttab-personal.desktop" ] && echo var || echo yok)"
    if command -v xmodmap >/dev/null 2>&1; then
        if xmodmap -pm 2>/dev/null | grep -qE '^mod1[[:space:]]+.*Alt'; then
            en_tr "Alt mapping: mod1 contains Alt (correct)" "Alt eslesmesi: mod1 Alt iceriyor (dogru)"
        else
            en_tr "Alt mapping: Alt is NOT on mod1 - Alt+Tab cannot fire (installer repairs this)" \
                  "Alt eslesmesi: Alt mod1'de DEGIL - Alt+Tab tetiklenemez (kurulum bunu onarir)"
        fi
    fi
    say ""
    if [ -x "$DEST/check-install.sh" ]; then
        say "-- check-install.sh --"
        bash "$DEST/check-install.sh" 2>&1 | sed 's/^/   /'
    fi
    say "To install / Kurmak icin: bash install.sh"
    exit 0
fi

if [ "$SESSION_TYPE" = "wayland" ]; then
    say ""
    en_tr "WARNING: this is a Wayland session. The switcher grabs Alt+Tab on the X11 display, so under" \
          "UYARI: bu bir Wayland oturumu. Degistirici Alt+Tab'i X11 ekraninda tutar; bu nedenle Wayland"
    en_tr "Wayland only XWayland windows are visible and the shortcut may not work at all." \
          "altinda yalnizca XWayland pencereleri gorunur ve kisayol hic calismayabilir."
    en_tr "Use an X11/Xorg session for this app. Continuing in 5 seconds (Ctrl+C to stop)." \
          "Bu uygulama icin X11/Xorg oturumu kullanin. 5 saniye sonra devam ediliyor (durdurmak icin Ctrl+C)."
    sleep 5
fi

if [ "$(id -u)" -eq 0 ]; then
    say ""
    en_tr "WARNING: you are root. Run this as your normal desktop user instead; the app must own" \
          "UYARI: root'sunuz. Bunu normal masaustu kullanici olarak calistirin; uygulama sizin"
    en_tr "your desktop session (displays, autostart, ~/.alttab-linux all belong to that user)." \
          "oturumunuza ait olmali (ekran, otomatik baslatma, ~/.alttab-linux hepsi o kullanicinin)"
    exit 1
fi

# Fluxbox has its own proven script (keys file + startup + mod1 repair).
if [ "$WM" = "fluxbox" ] && [ -x "$SRC/setup-fluxbox.sh" ]; then
    say ""
    en_tr "Fluxbox detected - handing over to setup-fluxbox.sh" \
          "Fluxbox bulundu - setup-fluxbox.sh'e devrediliyor"
    exec bash "$SRC/setup-fluxbox.sh" "$@"
fi

say ""
say "== 1/5 Install to $DEST / $DEST icine kur =="
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$SRC"/. "$DEST"/
rm -rf "$DEST/__pycache__" "$DEST/tests/__pycache__"
chmod +x "$DEST/run.sh" "$DEST/setup-fluxbox.sh" "$DEST/install.sh" "$DEST/check-install.sh" 2>/dev/null || true
en_tr "tests:" "testler:"
( cd "$DEST" && python3 tests/test_logic.py 2>&1 | tail -2 | sed 's/^/   /' )
( cd "$DEST" && python3 tests/test_hotkey_logic.py 2>&1 | tail -2 | sed 's/^/   /' )

say "== 2/5 Alt modifier check / Alt modifier kontrolu =="
# Alt must be Mod1: with an empty mod1, nothing bound to Mod1 can ever fire.
# Alt Mod1 olmalidir: mod1 bosken Mod1'e bagli hicbir sey tetiklenemez.
if command -v xmodmap >/dev/null 2>&1; then
    if xmodmap -pm 2>/dev/null | grep -qE '^mod1[[:space:]]+.*Alt'; then
        en_tr "mod1 already contains Alt" "mod1 zaten Alt iceriyor"
    else
        xmodmap -e "clear control" -e "add control = Control_L Control_R" \
                 -e "clear mod1" -e "add mod1 = Alt_L" 2>/dev/null || true
        if xmodmap -pm 2>/dev/null | grep -qE '^mod1[[:space:]]+.*Alt'; then
            en_tr "mod1 repaired for this session" "mod1 bu oturum icin duzeltildi"
        else
            en_tr "WARNING: could not repair mod1" "UYARI: mod1 duzeltilemedi"
        fi
    fi
else
    en_tr "xmodmap not found - install x11-xserver-utils to let the installer check Alt/Mod1" \
          "xmodmap yok - Alt/Mod1 kontrolu icin x11-xserver-utils kurun"
fi

say "== 3/5 Free Alt+Tab from the window manager / Alt+Tab'i pencere yoneticisinden al =="
case "$WM" in
    *xfwm*|*xfce*)
        if command -v xfconf-query >/dev/null 2>&1; then
            xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt>Tab" -s "" 2>/dev/null \
                && en_tr "xfwm4: Alt+Tab unbound (xfconf)" "xfwm4: Alt+Tab baglamasi kaldirildi (xfconf)" \
                || en_tr "xfwm4: could not change the shortcut automatically" "xfwm4: kisayol otomatik degistirilemedi"
            en_tr "If it does not stick: Settings -> Window Manager -> Keyboard, clear 'Switch window for same application'." \
                  "Kalici olmazsa: Ayarlar -> Pencere Yoneticisi -> Klavye, 'Ayni uygulamanin pencerelerini degistir' kaydini temizleyin."
        fi
        ;;
    *marco*|*mate*)
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.mate.Marco.global-keybindings switch-windows 'disabled' 2>/dev/null \
                && en_tr "marco: switch-windows disabled" "marco: switch-windows kapatildi" \
                || en_tr "marco: could not change it automatically" "marco: otomatik degistirilemedi"
        fi
        ;;
    *muffin*|*cinnamon*)
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.cinnamon.desktop.keybindings.wm switch-windows "[]" 2>/dev/null \
                && en_tr "muffin: switch-windows disabled" "muffin: switch-windows kapatildi" \
                || en_tr "muffin: could not change it automatically" "muffin: otomatik degistirilemedi"
        fi
        ;;
    *mutter*|*gnome*)
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.gnome.desktop.wm.keybindings switch-applications "[]" 2>/dev/null || true
            gsettings set org.gnome.desktop.wm.keybindings switch-windows "[]" 2>/dev/null || true
            gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "[]" 2>/dev/null || true
            en_tr "mutter: switch-applications / switch-windows disabled" "mutter: switch uygulama/pencere kisayollari kapatildi"
        fi
        ;;
    *kwin*|*plasma*|*kde*)
        en_tr "KWin: clear it manually - System Settings -> Shortcuts -> KWin -> 'Walk Through Windows'." \
              "KWin: elle temizleyin - Sistem Ayarlari -> Kisayollar -> KWin -> 'Walk Through Windows'."
        ;;
    *openbox*)
        en_tr "Openbox: Alt+Tab is not bound by default. If yours binds it, remove it from ~/.config/openbox/rc.xml and run: openbox --reconfigure" \
              "Openbox: Alt+Tab varsayilan olarak bagli degil. Bagliysa ~/.config/openbox/rc.xml'den silin ve: openbox --reconfigure"
        ;;
    *i3*|*sway*|*jwm*|*icewm*|*unknown*|"")
        en_tr "Unknown/unsupported window manager: remove its Alt+Tab binding yourself, then restart it." \
              "Bilinmeyen/desteklenmeyen pencere yoneticisi: Alt+Tab baglamasini kendiniz kaldirin ve yeniden baslat."
        ;;
    *)
        en_tr "Window manager '$WM': no automatic rule - remove its Alt+Tab binding manually." \
              "Pencere yoneticisi '$WM': otomatik kural yok - Alt+Tab baglamasini elle kaldirin."
        ;;
esac

say "== 4/5 Autostart / Otomatik baslatma =="
mkdir -p "$HOME/.config/autostart"
sed "s|^Exec=.*|Exec=$DEST/run.sh --debug|" "$DEST/alttab-personal.desktop" > "$HOME/.config/autostart/alttab-personal.desktop"
en_tr "written: ~/.config/autostart/alttab-personal.desktop" "yazildi: ~/.config/autostart/alttab-personal.desktop"
if [ -f "$HOME/.fluxbox/startup" ]; then
    en_tr "note: a Fluxbox startup file exists too; this desktop looks like Fluxbox, so re-run with --wm fluxbox if Alt+Tab is already taken by Fluxbox." \
          "not: Fluxbox startup dosyasi da var; masaustu Fluxbox'a benziyorsa ve Alt+Tab'i Fluxbox tutuyorsa --wm fluxbox ile tekrar calistirin."
fi

say "== 5/5 Result / Sonuc =="
if [ "$MODE" = "start" ]; then
    pkill -f 'alttab_personal.py' 2>/dev/null || true
    sleep 0.3
    setsid nohup "$DEST/run.sh" --debug > "$DEST/alttab.log" 2>&1 &
    sleep 2
    if pgrep -f 'alttab_personal.py' >/dev/null 2>&1; then
        en_tr "running (log: ~/.alttab-linux/alttab.log)" "calisiyor (gunluk: ~/.alttab-linux/alttab.log)"
        tail -4 "$DEST/alttab.log" | sed 's/^/   /'
    else
        en_tr "NOT RUNNING - log:" "BASLAMADI - gunluk:"
        tail -12 "$DEST/alttab.log" | sed 's/^/   /'
    fi
else
    en_tr "not started yet - start it yourself with:" "henuz baslatilmadi - kendiniz baslatin:"
    say "     $DEST/run.sh &"
    en_tr "or re-run this script with --start" "ya da bu betigi --start ile tekrar calistirin"
fi

say ""
say "-- verification / dogrulama --"
[ -x "$DEST/check-install.sh" ] && bash "$DEST/check-install.sh" 2>&1 | sed 's/^/   /'
say ""
en_tr "Hold Alt and press Tab to switch windows. Esc cancels, Return raises the selection." \
      "Alt'i basili tutup Tab'a basin. Esc iptal eder, Return secimi one getirir."
en_tr "Logout/login to confirm autostart works." "Otomatik baslatmayi dogrulamak icin oturumu kapatip acin."
en_tr "Uninstall: rm -rf ~/.alttab-linux ~/.config/autostart/alttab-personal.desktop" \
      "Kaldirma: rm -rf ~/.alttab-linux ~/.config/autostart/alttab-personal.desktop"
