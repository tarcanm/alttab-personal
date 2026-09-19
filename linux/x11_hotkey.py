"""Global Alt+Tab hook for X11, plus a keyboard grab while the panel is open.
X11 için global Alt+Tab kancası; panel açıkken klavye grab'i.

Why it works this way / Neden böyle:
- A passive grab on Mod1+Tab (with the Lock/Mod2 variants, so NumLock does not break it) tells the
  X server to route that combination to us instead of the focused window.
  Lock/Mod2 varyasyonlarıyla birlikte Mod1+Tab üzerine pasif grab, X sunucusunun bu kombinasyonu
  odaktaki pencere yerine bize yönlendirmesini sağlar.
- On the first press we take an active keyboard grab, so every key goes to us while the panel is up.
  İlk basışta aktif klavye grab'i alırız, böylece panel açıkken tüm tuşlar bize gelir.
- Alt release is detected two ways: the KeyRelease event, plus a QueryKeymap poll as ground truth.
  Alt bırakılması iki yolla algılanır: KeyRelease olayı ve kesin bilgi için QueryKeymap yoklaması.
"""

import time

import gi

gi.require_version("Gtk", "3.0")

from gi.repository import GLib  # noqa: E402
from Xlib import X, XK, display  # noqa: E402
from Xlib.error import BadAccess, XError  # noqa: E402

from logic import is_auto_repeat  # noqa: E402

# Keyboard keys we care about / İlgilendiğimiz tuşlar
KEYSYMS = {
    "tab": "Tab",
    "escape": "Escape",
    "return": "Return",
    "left": "Left",
    "right": "Right",
    "alt": "Alt_L",
}

# Modifier combinations the passive grab must cover / Pasif grab'in kapsaması gereken varyasyonlar
GRAB_EXTRA_MODIFIERS = (0, X.LockMask, X.Mod2Mask, X.LockMask | X.Mod2Mask)

POLL_INTERVAL_MS = 60


class HotKeyUnavailable(Exception):
    """Raised when the key combination is owned by someone else.
    Kombinasyon başkasına ait olduğunda yükseltilir."""


class X11HotKey:
    def __init__(self, on_start, on_cycle, on_commit, on_cancel, log=print):
        self.on_start = on_start
        self.on_cycle = on_cycle
        self.on_commit = on_commit
        self.on_cancel = on_cancel
        self.log = log

        self.display = None
        self.root = None
        self.keycodes = {}
        self.alt_keycode = None
        self.active = False
        self.keyboard_grabbed = False
        self._prev_keycode = None
        self._prev_time = None
        self._source_id = None
        self._poll_id = None
        self._x_errors = []
        self.last_event_time = 0

    # MARK: - Lifecycle / Yaşam döngüsü

    def start(self):
        """Open the display and install the passive grab. Raises HotKeyUnavailable on failure.
        Ekranı aç ve pasif grab'i kur. Başarısızsa HotKeyUnavailable yükseltir."""
        self.display = display.Display()
        self.root = self.display.screen().root
        self.display.set_error_handler(self._collect_x_error)

        for name, keysym in KEYSYMS.items():
            keycode = self.display.keysym_to_keycode(XK.string_to_keysym(keysym))
            if keycode:
                self.keycodes[name] = keycode
        self.alt_keycode = self.keycodes.get("alt")

        tab_keycode = self.keycodes.get("tab")
        if not tab_keycode:
            raise HotKeyUnavailable("Tab keycode not found / Tab tuş kodu bulunamadı")

        for extra in GRAB_EXTRA_MODIFIERS:
            self.root.grab_key(
                tab_keycode,
                X.Mod1Mask | extra,
                True,
                X.GrabModeAsync,
                X.GrabModeAsync,
            )
        self.display.sync()

        for error in self._x_errors:
            if isinstance(error, BadAccess):
                raise HotKeyUnavailable("BadAccess on Mod1+Tab grab")

        self._source_id = GLib.io_add_watch(self.display.fileno(), GLib.IO_IN, self._on_x_events)
        return True

    def stop(self):
        """Remove the grab, release the keyboard and close the display.
        Grab'i kaldır, klavyeyi bırak ve ekranı kapat."""
        if self._source_id is not None:
            GLib.source_remove(self._source_id)
            self._source_id = None
        self._stop_poll()
        if self.display is not None:
            if self.keyboard_grabbed:
                self.display.ungrab_keyboard(X.CurrentTime)
                self.keyboard_grabbed = False
            tab_keycode = self.keycodes.get("tab")
            if tab_keycode:
                for extra in GRAB_EXTRA_MODIFIERS:
                    self.root.ungrab_key(tab_keycode, X.Mod1Mask | extra)
            self.display.sync()
            self.display.close()
            self.display = None

    # MARK: - Grabs / Grab'ler

    def _grab_keyboard(self):
        if self.keyboard_grabbed or self.display is None:
            return
        self.display.grab_keyboard(False, X.GrabModeAsync, X.GrabModeAsync, X.CurrentTime)
        self.display.sync()
        self.keyboard_grabbed = True

    def _ungrab_keyboard(self):
        if not self.keyboard_grabbed or self.display is None:
            return
        self.display.ungrab_keyboard(X.CurrentTime)
        self.display.sync()
        self.keyboard_grabbed = False

    def alt_is_down(self):
        """Ground truth for "is Alt still held": one QueryKeymap round trip.
        "Alt hâlâ basılı mı" sorusunun kesin cevabı: tek QueryKeymap gidiş-dönüşü."""
        if self.display is None or self.alt_keycode is None:
            return False
        bitmap = self.display.query_keymap()
        if isinstance(bitmap, int):  # very old python-xlib / eski python-xlib
            return bool(bitmap & (1 << self.alt_keycode))
        try:
            return bool(bitmap[self.alt_keycode // 8] & (1 << (self.alt_keycode % 8)))
        except (TypeError, IndexError):
            return False

    # MARK: - Event handling / Olay işleme

    def _on_x_events(self, fd, condition):
        """GLib watch callback / GLib watch geri çağrısı."""
        while self.display is not None and self.display.pending_events():
            event = self.display.next_event()
            self._handle(event)
        return True

    def _handle(self, event):
        # Remember the server timestamp: switching windows with a stale one upsets
        # focus-stealing prevention in some window managers.
        # Sunucu zaman damgasını sakla: bazı pencere yöneticileri eski damgayla yapılan
        # pencere geçişini "odak çalma" sayıp reddeder.
        if getattr(event, "time", None):
            self.last_event_time = event.time
        if event.type == X.KeyPress:
            self._handle_press(event)
        elif event.type == X.KeyRelease:
            self._handle_release(event)

    def _handle_press(self, event):
        keycode = event.detail
        if is_auto_repeat(self._prev_keycode, self._prev_time, keycode, event.time):
            self._prev_keycode, self._prev_time = keycode, event.time
            return
        self._prev_keycode, self._prev_time = keycode, event.time

        if not self.active:
            if keycode == self.keycodes.get("tab"):
                self._activate()
            return

        shift = bool(event.state & X.ShiftMask)
        if keycode == self.keycodes.get("tab"):
            self.on_cycle(-1 if shift else 1)
        elif keycode == self.keycodes.get("left"):
            self.on_cycle(-1)
        elif keycode == self.keycodes.get("right"):
            self.on_cycle(1)
        elif keycode == self.keycodes.get("escape"):
            self._end(commit=False)
        elif keycode == self.keycodes.get("return"):
            self._end(commit=True)

    def _handle_release(self, event):
        if self.active and self.alt_keycode is not None and event.detail == self.alt_keycode:
            self._end(commit=True)

    def _activate(self):
        self.active = True
        self._grab_keyboard()
        self.on_start()
        self._start_poll()

    def _end(self, commit):
        if not self.active:
            return
        self.active = False
        self._stop_poll()
        self._ungrab_keyboard()
        if commit:
            self.on_commit()
        else:
            self.on_cancel()

    # MARK: - Alt release watchdog / Alt bırakma bekçisi

    def _start_poll(self):
        self._poll_id = GLib.timeout_add(POLL_INTERVAL_MS, self._poll_alt)

    def _stop_poll(self):
        if self._poll_id is not None:
            GLib.source_remove(self._poll_id)
            self._poll_id = None

    def _poll_alt(self):
        if not self.active:
            self._poll_id = None
            return False
        if not self.alt_is_down():
            self._end(commit=True)
            self._poll_id = None
            return False
        return True

    def _collect_x_error(self, error, request):
        self._x_errors.append(error)
