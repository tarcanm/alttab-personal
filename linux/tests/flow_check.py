"""Integration check that needs a real display: does committing a selection raise the window?

Gerçek bir ekran gerektiren entegrasyon kontrolü: seçimi uygulamak pencereyi öne getiriyor mu?

Run it inside your graphical session / Grafik oturumunun içinde çalıştır:
    python3 tests/flow_check.py [index]

It starts the switcher flow without the hotkey (no grab), prints the active window before and after,
and restores the original window at the end.
Kanca kurmadan değiştirici akışını başlatır, önce/sonra aktif pencereyi yazar ve sonunda
başlangıçtaki pencereye geri döner.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402

from logic import BIDI_CONTROLS, cycle_index  # noqa: E402


def clean(text):
    """Strip invisible bidi controls so titles can be compared.

    Görünmez bidi karakterleri temizle; böylece başlıklar kıyaslanabilir."""
    return (text or "").translate({ord(char): None for char in BIDI_CONTROLS})


def active_title(screen):
    window = screen.get_active_window()
    return clean(window.get_name()) if window is not None else None


def main(argv):
    if not Gtk.init_check()[0]:
        print("no display / ekran yok", file=sys.stderr)
        return 3

    from alttab_personal import Switcher

    switcher = Switcher(debug=True)
    switcher.entries = switcher.windows.refresh()
    if not switcher.entries:
        print("no windows / pencere yok", file=sys.stderr)
        return 0

    before = active_title(switcher.windows.screen)
    print(f"windows: {len(switcher.entries)}")
    for index, entry in enumerate(switcher.entries):
        print(f"  [{index}] {entry.app_name} | {entry.title}" + (" (minimized)" if entry.minimized else ""))

    target = int(argv[0]) if argv else cycle_index(0, 1, len(switcher.entries))
    switcher.selected = target
    chosen = switcher.entries[target]
    print(f"\ntarget [{target}] {chosen.app_name} | {chosen.title}")
    print("before:", before)

    switcher.show_panel()
    for _ in range(20):
        while Gtk.events_pending():
            Gtk.main_iteration_do(False)
        time.sleep(0.05)
    switcher.panel.hide()

    switcher.on_commit()
    time.sleep(0.8)
    while Gtk.events_pending():
        Gtk.main_iteration_do(False)

    after = active_title(switcher.windows.screen)
    print("after :", after)
    # The panel shortens long titles, so compare the prefix the panel shows.
    # Panel uzun başlıkları kısalttığı için gösterilen öneki kıyaslarız.
    ok = (after or "").startswith(chosen.title[:60])
    print("RESULT:", "OK (raised the chosen window)" if ok else "FAILED (active window did not change)")
    if not ok:
        print("note: some window managers refuse activation requests they consider focus stealing")

    # Put things back the way they were / Ortamı eski haline getir
    for window in switcher.windows.screen.get_windows():
        if before is not None and clean(window.get_name()) == before:
            window.activate(switcher.windows.server_time())
            print("restored:", before)
            break
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
