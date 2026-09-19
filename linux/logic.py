"""Pure helpers for the switcher: no X11, no GTK, so they stay unit-testable.
Saf yardımcılar: X11 ve GTK yok, bu yüzden birim testleriyle doğrulanabilir.
"""

# Repeated KeyPress events from X auto-repeat arrive with an identical server timestamp
# within this window, and are ignored so a held Tab does not spin through the list.
# X auto-repeat kaynaklı tekrar KeyPress olayları bu pencere içinde aynı sunucu zaman
# damgasıyla gelir ve yok sayılır; böylece basılı tutulan Tab listede fırlamaz.
AUTO_REPEAT_WINDOW_MS = 30

# Invisible bidi control characters (U+200E/200F, U+202A-U+202E, U+2066-U+2069) appear in some
# window titles, for example YouTube pages, and would render as stray gaps.
# Bazı pencere başlıklarında (ör. YouTube sayfaları) görünmez bidi kontrol karakterleri
# (U+200E/200F, U+202A-U+202E, U+2066-U+2069) bulunur ve panelde tuhaf boşluklar bırakır.
BIDI_CONTROLS = "\u200e\u200f\u202a\u202b\u202c\u202d\u202e\u2066\u2067\u2068\u2069"

# How many rows the panel shows at once.
# Panelin aynı anda gösterdiği satır sayısı.
MAX_VISIBLE_ROWS = 12


def cycle_index(index, delta, count):
    """Move the selection, wrapping around.

    Seçimi döndürerek ilerlet.

    >>> cycle_index(0, 1, 3)
    1
    >>> cycle_index(0, -1, 3)
    2
    >>> cycle_index(5, 1, 0)
    0
    """
    if count <= 0:
        return 0
    return (index + delta) % count


def initial_index(count):
    """Index selected on the first press: the previous window, Windows-style.

    İlk basışta seçilen index: Windows mantığıyla bir önceki pencere.

    >>> initial_index(1)
    0
    >>> initial_index(4)
    1
    """
    return 1 if count > 1 else 0


def visible_range(selected, count, max_visible=MAX_VISIBLE_ROWS):
    """Return the (start, end) slice that keeps the selection centered.

    Seçimi ortada tutan (start, end) dilimini döndür.

    >>> visible_range(0, 5, 12)
    (0, 5)
    >>> visible_range(20, 30, 12)
    (14, 26)
    """
    if count <= 0:
        return 0, 0
    if count <= max_visible:
        return 0, count
    start = selected - max_visible // 2
    start = max(0, min(start, count - max_visible))
    return start, start + max_visible


def clamp_label(text, max_chars=80):
    r"""Collapse whitespace and shorten long window titles.

    Boşlukları sadeleştir ve uzun pencere başlıklarını kısalt.

    >>> clamp_label("  a\n b  ")
    'a b'
    >>> clamp_label("x" * 5, 4)
    'xxx…'
    """
    text = (text or "").translate({ord(ch): None for ch in BIDI_CONTROLS})
    clean = " ".join(text.split())
    if len(clean) <= max_chars:
        return clean
    return clean[: max_chars - 1] + "\u2026"


def humanize_app_name(raw, fallback=""):
    """Turn a WM_CLASS value into something readable.

    WM_CLASS değerini okunur hale getir.

    >>> humanize_app_name("google-chrome")
    'Google Chrome'
    >>> humanize_app_name("org.gnome.Nautilus")
    'Nautilus'
    >>> humanize_app_name("RustDesk")
    'RustDesk'
    >>> humanize_app_name("")
    ''
    >>> humanize_app_name("", "Application")
    'Application'
    """
    name = (raw or "").strip()
    if not name:
        return fallback
    if "." in name:  # reverse-DNS class such as org.gnome.Nautilus / ters-DNS sınıfı
        name = name.split(".")[-1]
    words = []
    for word in name.replace("-", " ").replace("_", " ").split():
        if word.islower() or word.isupper():
            words.append(word.capitalize())
        else:
            words.append(word)  # keep intentional casing / bilinçli yazımı koru
    return " ".join(words)


def app_name_is_useless(name, title):
    """Does libwnck's application name look like it just echoed the window title?

    libwnck'in uygulama adı sadece pencere başlığını mı tekrarlamış?

    >>> app_name_is_useless("user@host: ~", "user@host: ~")
    True
    >>> app_name_is_useless("Thunar", "user - Thunar")
    False
    >>> app_name_is_useless("", "Thunar")
    True
    >>> app_name_is_useless("x" * 45, "some window")
    True
    """
    if not name:
        return True
    if name.strip().lower() == (title or "").strip().lower():
        return True
    return len(name) > 40  # window titles are long, application names are not / başlıklar uzundur


MODIFIER_NAMES = ("Shift", "Lock", "Control", "Mod1", "Mod2", "Mod3", "Mod4", "Mod5")


def modifier_name_for_keycode(mapping, keycode):
    """Name of the modifier set that contains keycode, or None when it is in none.

    keycode'u içeren modifier kümesinin adı; hiçbirinde değilse None.

    On some sessions Alt_L ends up inside "Control" and mod1 is left empty; then nothing bound to
    Mod1 (our Alt+Tab grab, Fluxbox's own NextWindow) can ever fire.
    Bazı oturumlarda Alt_L "Control" içinde kalır ve mod1 boş kalır; o zaman Mod1'e bağlı hiçbir şey
    (bizim Alt+Tab grab'imiz, Fluxbox'ın NextWindow'u) tetiklenemez.

    >>> modifier_name_for_keycode([[50, 62], [66], [37, 64], [], [77]], 64)
    'Control'
    >>> modifier_name_for_keycode([[50, 62], [66], [37], [64]], 64)
    'Mod1'
    >>> modifier_name_for_keycode([[50, 62], [66], [37]], 64)
    """
    if keycode is None:
        return None
    for index, keycodes in enumerate(mapping):
        if index >= len(MODIFIER_NAMES):
            break
        for candidate in keycodes:
            if candidate and int(candidate) == keycode:
                return MODIFIER_NAMES[index]
    return None


def is_auto_repeat(prev_keycode, prev_time, keycode, time):
    """Is this event an auto-repeat artifact of the previous one?

    Bu olay bir öncekinin auto-repeat kopyası mı?

    >>> is_auto_repeat(23, 100, 23, 100)
    True
    >>> is_auto_repeat(23, 100, 23, 140)
    False
    >>> is_auto_repeat(None, None, 23, 100)
    False
    """
    if prev_keycode is None or prev_time is None:
        return False
    return prev_keycode == keycode and abs(prev_time - time) <= AUTO_REPEAT_WINDOW_MS
