"""AltTab Personal for Linux (X11): hold Alt, press Tab, release to switch.
AltTab Personal Linux sürümü (X11): Alt'ı basılı tut, Tab'a bas, bırakınca geç.

Same behaviour as the macOS version / macOS sürümüyle aynı davranış:
  Alt down + Tab          open the panel, select the previous window
  Tab / Shift+Tab         move forward / backward
  Left / Right arrows     move backward / forward
  Release Alt (or Return) raise the selected window
  Esc                     cancel

Usage / Kullanım:
  ./run.sh                 start the switcher
  ./run.sh --print-windows print the window list and exit (diagnostics, no hotkey needed)
  ./run.sh --version
"""

import argparse
import os
import sys

import gi

gi.require_version("Gtk", "3.0")

from gi.repository import GLib, Gtk  # noqa: E402

from l import L_  # noqa: E402
from logic import initial_index, cycle_index  # noqa: E402
from panel import SwitcherPanel  # noqa: E402
from window_list import WindowList  # noqa: E402
from x11_hotkey import HotKeyUnavailable, X11HotKey  # noqa: E402

VERSION = "0.1.0"


class Switcher:
    def __init__(self, l=L_, debug=False):
        self.l = l
        self.debug = debug
        self.windows = WindowList(l)
        self.panel = SwitcherPanel(l)
        self.entries = []
        self.selected = 0
        self.hotkey = X11HotKey(
            on_start=self.on_start,
            on_cycle=self.on_cycle,
            on_commit=self.on_commit,
            on_cancel=self.on_cancel,
            log=self.log,
        )

    def log(self, *args):
        if self.debug:
            print(*args, file=sys.stderr, flush=True)

    # MARK: - Switcher flow / Değiştirici akışı

    def on_start(self):
        self.entries = self.windows.refresh()
        if not self.entries:
            self.log(self.l.no_windows)
            self.panel.hide()
            return
        self.selected = initial_index(len(self.entries))
        self.show_panel()

    def on_cycle(self, delta):
        if not self.entries:
            return
        self.selected = cycle_index(self.selected, delta, len(self.entries))
        self.show_panel()

    def on_commit(self):
        entry = self.entries[self.selected] if self.entries else None
        self.panel.hide()
        self.entries = []
        if entry is not None:
            ok = self.windows.activate(entry, self.hotkey.last_event_time)
            self.log("activate", entry.xid, entry.title, "->", ok)

    def on_cancel(self):
        self.panel.hide()
        self.entries = []

    def show_panel(self):
        self.panel.render(self.entries, self.selected)
        natural = self.panel.window.get_preferred_size()[1]
        x, y = self.windows.panel_origin(max(natural.width, 320), natural.height)
        self.panel.show_centered(x, y)

    # MARK: - Lifecycle / Yaşam döngüsü

    def run(self):
        if not Gtk.init_check()[0]:
            print(self.l.display_missing, file=sys.stderr)
            return 3
        try:
            self.hotkey.start()
        except HotKeyUnavailable as exc:
            self.log("hotkey unavailable:", exc)
            print(self.l.grab_unavailable, file=sys.stderr)
            return 2
        except Exception as exc:  # X connection problems / X bağlantı sorunları
            self.log("hotkey error:", exc)
            print(self.l.display_missing, file=sys.stderr)
            return 3

        print(self.l.started, flush=True)
        try:
            Gtk.main()
        except KeyboardInterrupt:
            pass
        finally:
            self.hotkey.stop()
        return 0


def print_windows():
    """Diagnostic mode: dump the window list without installing the hotkey.
    Teşhis modu: kanca kurmadan pencere listesini dök."""
    Gtk.init_check()
    windows = WindowList(L_)
    entries = windows.refresh()
    print(f"{len(entries)} window(s) / pencere")
    for index, entry in enumerate(entries):
        flags = " minimized" if entry.minimized else ""
        print(f"  [{index}] xid=0x{entry.xid:x} app={entry.app_name!r} title={entry.title!r}{flags}")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="alttab-personal",
        description=L_.pick(
            "Windows-style Alt+Tab window switcher for X11.",
            "X11 için Windows tarzı Alt+Tab pencere değiştirici.",
        ),
    )
    parser.add_argument("--version", action="store_true", help="print version / sürümü yaz")
    parser.add_argument(
        "--print-windows",
        action="store_true",
        help="print the window list and exit / pencere listesini yaz ve çık",
    )
    parser.add_argument("--debug", action="store_true", help="verbose logging / ayrıntılı günlük")
    args = parser.parse_args(argv)

    if args.version:
        print(f"AltTab Personal (Linux) {VERSION}")
        return 0
    if args.print_windows:
        return print_windows()
    if not os.environ.get("DISPLAY"):
        print(L_.display_missing, file=sys.stderr)
        return 3
    return Switcher(debug=args.debug).run()


if __name__ == "__main__":
    sys.exit(main())
