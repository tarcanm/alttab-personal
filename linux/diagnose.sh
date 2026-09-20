#!/usr/bin/env bash
# AltTab Personal (Linux) self check. Reports state by default; --fix updates the clone, installs,
# starts the app and then reports. English first, Turkish second.
# AltTab Personal (Linux) kendi kendini kontrol. Varsayilan olarak durumu raporlar; --fix klonu
# gunceller, kurulumu yapar, uygulamayi baslatir ve sonra raporlar. Once Ingilizce, sonra Turkce.
set -u

REPO_URL="https://github.com/tarcanm/alttab-personal.git"
CLONE_DIR="${ALTTAB_CLONE:-$HOME/alttab-personal}"
DEST="$HOME/.alttab-linux"
FIX=0
for arg in "$@"; do
    case "$arg" in
        --fix) FIX=1 ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    esac
done

say() { echo "$@"; }

if [ "$FIX" = "1" ]; then
    say "== 1/3 Update the clone / Klonu guncelle"
    if [ -d "$CLONE_DIR/.git" ]; then
        if git -C "$CLONE_DIR" pull --ff-only 2>&1 | sed 's/^/   /'; then :; fi
    else
        git clone "$REPO_URL" "$CLONE_DIR" 2>&1 | sed 's/^/   /'
    fi
    say "== 2/3 Install and start / Kur ve baslat"
    if [ -f "$CLONE_DIR/linux/install.sh" ]; then
        bash "$CLONE_DIR/linux/install.sh" --start 2>&1 | sed 's/^/   /'
    else
        say "   install.sh not found / bulunamadi: $CLONE_DIR/linux/install.sh"
    fi
    say "== 3/3 Report / Rapor"
fi

WM=""
if command -v xprop >/dev/null 2>&1; then
    WM_ID=$(xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | sed 's/.*# //')
    if [ -n "${WM_ID:-}" ]; then
        WM=$(xprop -id "$WM_ID" _NET_WM_NAME 2>/dev/null | sed 's/.*= //; s/"//g')
    fi
fi

say "AltTab Personal - durum raporu / state report"
say "   tarih/date      : $(date)"
say "   kullanici/user  : ${USER:-?}   HOME=$HOME"
say "   oturum/session  : DISPLAY=${DISPLAY:-<empty>}  XAUTHORITY=${XAUTHORITY:-<default>}  desktop=${XDG_CURRENT_DESKTOP:-<empty>}"
say "   pencere yn / wm : ${WM:-<unknown>}"
say "   klon/clone      : $CLONE_DIR  $(git -C "$CLONE_DIR" log --oneline -1 2>/dev/null || echo '(klon yok / no clone)')"
say "   kurulum/install : $([ -x "$DEST/run.sh" ] && echo 'VAR (installed)' || echo 'YOK (not installed)')   $DEST"
if [ -f "$DEST/alttab.log" ]; then
    say "   log dosyasi     : $(stat -c '%s bayt, son degisiklik %y' "$DEST/alttab.log" 2>/dev/null | cut -c1-40)"
else
    say "   log dosyasi     : YOK (uygulama hic baslamamis / app never started)"
fi
RUNNING=$(pgrep -u "$(id -u)" -f '^python3 alttab_personal.py' 2>/dev/null | tr '\n' ' ')
say "   surec/process   : ${RUNNING:-YOK (not running)}"
STARTUP_FILE="$HOME/.fluxbox/startup"
say "   ~/.fluxbox/startup        : $([ -f "$STARTUP_FILE" ] && echo 'var' || echo 'YOK')"
if [ -f "$STARTUP_FILE" ]; then
    say "   startup shebang/izin      : $(head -1 "$STARTUP_FILE" 2>/dev/null) $([ -x "$STARTUP_FILE" ] && echo '(calistirilabilir)' || echo '(calistirilamaz)')"
    EXEC_LN=$(grep -nE '^[[:space:]]*exec[[:space:]]+[^[:space:]]*fluxbox' "$STARTUP_FILE" 2>/dev/null | head -1 | cut -d: -f1)
    BLK_LN=$(grep -n '>>> alttab-personal >>>' "$STARTUP_FILE" 2>/dev/null | head -1 | cut -d: -f1)
    say "   exec fluxbox satiri       : ${EXEC_LN:-YOK}   AltTab blogu: ${BLK_LN:-YOK}"
    if [ -n "${BLK_LN:-}" ] && [ -n "${EXEC_LN:-}" ] && [ "$BLK_LN" -gt "$EXEC_LN" ]; then
        say "   >>> SORUN: blok 'exec fluxbox'tan SONRA; girişte hic calismaz <<<"
    fi
fi
STARTLINES=$(grep -c 'alttab' "$HOME/.fluxbox/startup" 2>/dev/null || true)
say "   startup icinde alttab     : ${STARTLINES:-0} satir"
say "   ~/.fluxbox/keys           : $([ -f "$HOME/.fluxbox/keys" ] && echo 'var' || echo 'YOK')"
KEYTAB=$(grep -cE '^[[:space:]]*Mod1[^:]*Tab[[:space:]]*:' "$HOME/.fluxbox/keys" 2>/dev/null || true)
say "   aktif Mod1+Tab baglamasi  : ${KEYTAB:-0} (0 olmali / should be 0)"
say "   XDG kaydi/entry           : $([ -f "$HOME/.config/autostart/alttab-personal.desktop" ] && echo 'var' || echo 'YOK')"
say "   mod1 satiri               : $(xmodmap -pm 2>/dev/null | grep -E '^mod1' || echo '?')"
if [ -f "$DEST/alttab.log" ]; then
    say "   log son satirlar / last lines:"
    tail -6 "$DEST/alttab.log" | sed 's/^/     /'
fi

say ""
if [ ! -x "$DEST/run.sh" ]; then
    say "SONUC: kurulum yok / not installed."
    say "       calistir / run:  bash \"$CLONE_DIR/linux/install.sh\" --start"
elif [ -n "$RUNNING" ]; then
    say "SONUC: uygulama calisiyor (PID $RUNNING) / app is running."
    say "       Alt+Tab'i dene; calismazsa yukaridaki log satirlarina bak / try Alt+Tab, else check the log above."
else
    say "SONUC: kurulum var ama surec yok / installed, process not running."
    say "       elle baslat / start by hand:"
    say "         nohup \"$DEST/run.sh\" --debug >> \"$DEST/alttab.log\" 2>&1 &"
fi
say "Bu ciktiyi Hermes'e yapistir. / Paste this output back to Hermes."
