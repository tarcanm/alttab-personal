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

from l import L_  # noqa: E402
from logic import initial_index, cycle_index  # noqa: E402

# DISPLAY has to be resolved *before* GTK is imported. GDK caches the "no display" state while being
# imported, and afterwards Gtk.init_check() reports success while creating the very first window
# fails with "Gtk couldn't be initialized". Setting the variable later does not help.
# DISPLAY, GTK import edilmeden ÖNCE çözülmelidir. GDK import edilirken "ekran yok" durumunu önbelleğe
# alır; sonrasında Gtk.init_check() başarı bildirir ama ilk pencere oluşturma "Gtk couldn't be
# initialized" ile başarısız olur. Değişkeni sonra ayarlamak işe yaramaz.
DISPLAY_GUESSED = None


def ensure_display():
    """Return the display to use, guessing the usual local one when DISPLAY is unset.

    Kullanılacak ekranı döndür; DISPLAY tanımsızsa olağan yerel ekranı tahmin et.
    """
    global DISPLAY_GUESSED
    current = os.environ.get("DISPLAY")
    if current:
        return current
    for candidate in (":0", ":1"):
        if os.path.exists(f"/tmp/.X11-unix/X{candidate[1:]}"):
            os.environ["DISPLAY"] = candidate
            DISPLAY_GUESSED = candidate
            return candidate
    return None


ensure_display()

import gi  # noqa: E402

gi.require_version("Gtk", "3.0")

from gi.repository import GLib, Gtk  # noqa: E402

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
            installed = self.hotkey.start()
        except HotKeyUnavailable as exc:
            self.log("hotkey unavailable:", exc)
            print(self.l.grab_unavailable, file=sys.stderr)
            return 2
        except Exception as exc:  # X connection problems and bugs / X bağlantı sorunları ve hatalar
            self.log("startup error:", exc)
            print(self.l.startup_failed(exc), file=sys.stderr)
            return 3

        # start() returns False when another program still owns Alt+Tab: the app keeps running and
        # retries with backoff, so the log must not claim it is ready.
        # start() başka bir program Alt+Tab'i tutuyorsa False döner: uygulama çalışmaya devam eder ve
        # artan aralıklarla tekrar dener; bu yüzden log "hazır" dememelidir.
        if installed:
            print(self.l.started, flush=True)
        else:
            print(self.l.grab_retrying, file=sys.stderr, flush=True)
        try:
            Gtk.main()
        except KeyboardInterrupt:
            pass
        finally:
            self.hotkey.stop()
        return 0


def display_reachable(display_name=None):
    """Open and close a real X connection, so we know the display works before building any GTK or
    libwnck object. Gtk.init_check() is not enough here: importing libwnck can leave GTK in a state
    where it reports success and the first window creation fails instead.

    Gerçek bir X bağlantısı açıp kapatır; böylece herhangi bir GTK veya libwnck nesnesi kurmadan önce
    ekranın çalıştığını biliriz. Burada Gtk.init_check() yeterli değil: libwnck importu GTK'yı öyle
    bir durumda bırakabiliyor ki başarı bildiriyor ve ilk pencere oluşturmada çöküyor.
    """
    try:
        from Xlib import display as xdisplay

        connection = xdisplay.Display(display_name) if display_name else xdisplay.Display()
        connection.close()
        return True
    except Exception:
        return False


def demo_panel(seconds=5):
    """Show the panel with the real window list and cycle through it, then quit.
    No hotkey is grabbed, so this is safe to run while the real instance is running:
    it exists to verify rendering, ordering and cycling without pressing Alt+Tab.

    Paneli gerçek pencere listesiyle göster, üzerinde gez, sonra çık. Kanca kurulmaz, bu yüzden
    gerçek örnek çalışırken de güvenle koşar: Alt+Tab'a basmadan çizimi, sırayı ve gezinmeyi
    doğrulamak için vardır.
    """
    if not Gtk.init_check()[0]:
        print(L_.display_missing, file=sys.stderr)
        return 3
    switcher = Switcher(debug=True)
    switcher.entries = switcher.windows.refresh()
    if not switcher.entries:
        print(L_.no_windows, file=sys.stderr)
        return 0
    switcher.selected = initial_index(len(switcher.entries))
    switcher.show_panel()
    print(f"panel demo: {len(switcher.entries)} window(s), {seconds}s", flush=True)

    state = {"ticks": 0, "max": max(1, int(seconds * 2))}

    def tick():
        state["ticks"] += 1
        if state["ticks"] > state["max"]:
            switcher.panel.hide()
            Gtk.main_quit()
            return False
        switcher.on_cycle(1)
        print(f"selected: {switcher.selected} {switcher.entries[switcher.selected].title!r}", flush=True)
        return True

    GLib.timeout_add(500, tick)
    Gtk.main()
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
    parser.add_argument(
        "--demo-panel",
        nargs="?",
        type=int,
        const=5,
        metavar="SECONDS",
        help="show the panel without grabbing the hotkey / kanca kurmadan paneli göster",
    )
    args = parser.parse_args(argv)

    if args.version:
        print(f"AltTab Personal (Linux) {VERSION}")
        return 0
    # Every mode except --version needs a display / --version dışındaki her mod ekran gerektirir
    if not ensure_display():
        print(L_.display_missing, file=sys.stderr)
        return 3
    if DISPLAY_GUESSED:
        print(L_.display_guessed(DISPLAY_GUESSED), file=sys.stderr)

    # Check the connection before building anything: creating a Gtk window or asking libwnck for the
    # screen without a working display crashes the process instead of failing with a message.
    # Bir şey kurmadan önce bağlantıyı doğrula: çalışan bir ekran olmadan Gtk penceresi veya libwnck
    # ekranı oluşturmak, mesajla hata vermek yerine süreci çökertir.
    if not display_reachable():
        print(L_.display_missing, file=sys.stderr)
        return 3
    if not Gtk.init_check()[0]:
        print(L_.display_missing, file=sys.stderr)
        return 3
    if args.print_windows:
        return print_windows()
    if args.demo_panel:
        return demo_panel(args.demo_panel)
    try:
        switcher = Switcher(debug=args.debug)
    except RuntimeError as exc:  # GTK refused to initialize / GTK başlatılamadı
        print(L_.startup_failed(exc), file=sys.stderr)
        return 3
    return switcher.run()


if __name__ == "__main__":
    sys.exit(main())
