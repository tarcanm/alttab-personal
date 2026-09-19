#!/usr/bin/env bash
# Launch AltTab Personal (Linux). English first, Turkish second.
# AltTab Personal (Linux) başlatıcısı. Önce İngilizce, sonra Türkçe.
set -u
cd "$(dirname "$0")" || exit 1
exec python3 alttab_personal.py "$@"
