#!/usr/bin/env bash
# Launch AltTab Personal (Linux). English first, Turkish second.
# AltTab Personal (Linux) başlatıcısı. Önce İngilizce, sonra Türkçe.
set -u
cd "$(dirname "$0")" || exit 1

# One instance only: the switcher grabs Mod1+Tab, so a second copy would fight the first one and make
# Alt+Tab look broken. One-shot helpers are exempt, they are meant to run next to the switcher.
# Tek örnek: değiştirici Mod1+Tab'ı tutar; ikinci bir kopya birinciyle çakışır ve Alt+Tab bozuk
# görünür. Tek seferlik yardımcılar muaf, onlar değiştiricinin yanında çalışmak için var.
DAEMON=1
for arg in "$@"; do
    case "$arg" in
        --print-windows|--demo-panel|--demo-panel=*|--version|-h|--help) DAEMON=0 ;;
    esac
done

if [ "$DAEMON" = "1" ] && command -v flock >/dev/null 2>&1; then
    exec 9>"$PWD/.alttab.lock"
    # -w waits a moment so a process that is shutting down does not look like a permanent block, and
    # the holder is reported: a silent "already running" hides where the running copy lives.
    # -w kisa sure bekler, boylece kapanmakta olan bir surec kalici engel gibi gorunmez; kilidi tutan
    # da yazilir: sessiz bir "already running" calisan kopyanin nerede oldugunu saklar.
    if ! flock -w 5 9; then
        HOLDER=""
        if command -v lsof >/dev/null 2>&1; then
            HOLDER=$(lsof -t "$PWD/.alttab.lock" 2>/dev/null | tr '\n' ' ')
        fi
        if [ -z "$HOLDER" ]; then
            HOLDER=$(pgrep -u "$(id -u)" -f '^python3 alttab_personal.py' 2>/dev/null | tr '\n' ' ')
        fi
        echo "AltTab Personal is already running (pid ${HOLDER:-unknown}); exiting /" >&2
        echo "zaten calisiyor (pid ${HOLDER:-bilinmiyor}); cikiliyor" >&2
        exit 0
    fi
fi

exec python3 alttab_personal.py "$@"
