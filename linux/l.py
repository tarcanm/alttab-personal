"""Localization helper. English first, Turkish second, same idea as Sources/L.swift.
Yerelleştirme yardımcısı. Önce İngilizce, sonra Türkçe; Sources/L.swift ile aynı mantık.
"""

import os


def _detect_turkish():
    """True when the session language starts with "tr".

    Oturum dili "tr" ile başlıyorsa True.
    """
    for var in ("LC_ALL", "LC_MESSAGES", "LANG"):
        value = os.environ.get(var)
        if value:
            return value.lower().startswith("tr")
    return False


class L:
    """Holds the strings for one language / Tek dil için metinleri tutar."""

    def __init__(self, turkish=None):
        self.turkish = _detect_turkish() if turkish is None else bool(turkish)

    def pick(self, en, tr):
        return tr if self.turkish else en

    # Labels shown in the panel / Panelde görünen etiketler
    @property
    def untitled_window(self):
        return self.pick("Untitled window", "Başlıksız pencere")

    @property
    def application(self):
        return self.pick("Application", "Uygulama")

    @property
    def minimized(self):
        return self.pick("minimized", "küçültülmüş")

    @property
    def navigation_hint(self):
        return self.pick(
            "Hold Alt, Tab to move, release to switch, Esc to cancel",
            "Alt basılı tut, Tab ile gez, bırak = geç, Esc iptal",
        )

    # Console messages / Konsol mesajları
    def window_count(self, total, shown):
        return self.pick(f"{total} windows, showing {shown}", f"{total} pencere, {shown} tanesi gösteriliyor")

    @property
    def no_windows(self):
        return self.pick("No windows to switch to.", "Geçilecek pencere yok.")

    @property
    def grab_unavailable(self):
        return self.pick(
            "Could not grab Alt+Tab: another program already owns that key combination "
            "(Fluxbox binds Mod1 Tab to NextWindow by default). Remove or rebind that line in "
            "~/.fluxbox/keys, reload the window manager, then start this app again.",
            "Alt+Tab alınamadı: bu tuş kombinasyonu başka bir programda kayıtlı "
            "(Fluxbox varsayılan olarak Mod1 Tab -> NextWindow bağlar). ~/.fluxbox/keys içindeki o "
            "satırı kaldır veya değiştir, pencere yöneticisini yenile, sonra bu uygulamayı tekrar başlat.",
        )

    @property
    def grab_retrying(self):
        return self.pick(
            "Alt+Tab is currently owned by another program (the window manager right after login, "
            "for example). Staying alive and retrying every few seconds; if it never clears, remove "
            "the Mod1 Tab line from ~/.fluxbox/keys and reload the window manager.",
            "Alt+Tab şu an başka bir programda (örneğin giriş sonrası pencere yöneticisi). Uygulama "
            "yaşıyor ve birkaç saniyede bir tekrar deniyor; hiç açılmazsa ~/.fluxbox/keys içindeki "
            "Mod1 Tab satırını kaldırıp pencere yöneticisini yenileyin.",
        )

    def alt_not_mod1(self, detail):
        """Warn when the Alt key does not produce Mod1: Alt+Tab can then never fire.

        Alt tuşu Mod1 üretmiyorsa uyar: o durumda Alt+Tab asla tetiklenemez."""
        en = ("Warning: the Alt key is not bound to Mod1 on this display (%s).\n"
              "Alt+Tab cannot fire until the modifier map is repaired:\n"
              "  xmodmap -e \"clear mod1\" -e \"add mod1 = Alt_L\"") 
        tr = ("Uyarı: bu ekranda Alt tuşu Mod1'e bağlı değil (%s).\n"
              "Modifier haritası düzeltilene kadar Alt+Tab tetiklenemez:\n"
              "  xmodmap -e \"clear mod1\" -e \"add mod1 = Alt_L\"")
        return en if self.english else tr

    @property
    def display_missing(self):
        return self.pick(
            "No X display available. Start this from a terminal inside your graphical session, "
            "as your desktop user (not root). Over SSH use:\n"
            "  DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority ~/.alttab-linux/run.sh &",
            "X ekranı yok. Bunu grafik oturumundaki bir terminalden, masaüstü kullanıcın olarak "
            "(root değil) başlat. SSH üzerinden:\n"
            "  DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority ~/.alttab-linux/run.sh &",
        )

    def display_guessed(self, name):
        return self.pick(f"DISPLAY was not set, trying {name}.", f"DISPLAY tanımlı değildi, {name} deneniyor.")

    def startup_failed(self, error):
        return self.pick(f"Could not start: {error}", f"Başlatılamadı: {error}")

    @property
    def started(self):
        return self.pick("AltTab Personal (Linux) is running. Hold Alt and press Tab.",
                         "AltTab Personal (Linux) çalışıyor. Alt basılı tutup Tab'a bas.")


L_ = L()
