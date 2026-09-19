"""Pure helpers for the switcher: no X11, no GTK, so they stay unit-testable.
Saf yardımcılar: X11 ve GTK yok, bu yüzden birim testleriyle doğrulanabilir.
"""

# Repeated KeyPress events from X auto-repeat arrive with an identical server timestamp
# within this window, and are ignored so a held Tab does not spin through the list.
# X auto-repeat kaynaklı tekrar KeyPress olayları bu pencere içinde aynı sunucu zaman
# damgasıyla gelir ve yok sayılır; böylece basılı tutulan Tab listede fırlamaz.
AUTO_REPEAT_WINDOW_MS = 30

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
    clean = " ".join((text or "").split())
    if len(clean) <= max_chars:
        return clean
    return clean[: max_chars - 1] + "\u2026"


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
