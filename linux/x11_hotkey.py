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

import sys
import time

import gi

gi.require_version("Gtk", "3.0")

from gi.repository import GLib  # noqa: E402
from Xlib import X, XK, display  # noqa: E402
from Xlib.error import BadAccess, XError  # noqa: E402

from logic import MODIFIER_NAMES, is_auto_repeat, modifier_name_for_keycode  # noqa: E402

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
    # Retry schedule for a blocked grab, in seconds. At login the window manager may still own
    # Alt+Tab for a moment, and giving up on the first BadAccess left the whole session without a
    # switcher: the app exited and nothing brought it back until the next manual start.
    # Engellenen grab icin tekrar deneme cizelgesi (saniye). Giris aninda pencere yoneticisi Alt+Tab'i
    # bir sure daha tutuyor olabilir; ilk BadAccess'te vazgecmek tum oturumu degistiricisiz
    # birakiyordu: uygulama cikiyor ve elle baslatilana kadar geri gelmiyordu.
    RETRY_DELAYS = (0.25, 0.5, 1, 2, 3, 5, 10, 20, 30)

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
        self._retry_id = None
        self._grabbing = False
        self._grabbed = False
        self._regrabbing = False
        self.last_event_time = 0

    # MARK: - Lifecycle / Yaşam döngüsü

    def start(self):
        """Open the display, watch its events, install the passive grab.

        Ekranı aç, olaylarını izle, pasif grab'i kur.

        Returns True when Alt+Tab is ours and False while another program still owns it: the app then
        stays alive and keeps retrying, because at login a window manager can hold the combination
        for a moment. HotKeyUnavailable is raised only for things nothing can retry.
        Alt+Tab bizdeyse True, başka bir programdaysa False döner: uygulama o durumda yaşamaya devam
        eder ve tekrar dener, çünkü giriş anında pencere yöneticisi kombinasyonu bir süre tutabilir.
        HotKeyUnavailable yalnızca tekrar denenemeyecek durumlar için yükseltilir."""
        self.display = display.Display()
        self.root = self.display.screen().root
        self.display.set_error_handler(self._collect_x_error)

        for name, keysym in KEYSYMS.items():
            keycode = self.display.keysym_to_keycode(XK.string_to_keysym(keysym))
            if keycode:
                self.keycodes[name] = keycode
        self.alt_keycode = self.keycodes.get("alt")

        if not self.keycodes.get("tab"):
            raise HotKeyUnavailable("Tab keycode not found / Tab tuş kodu bulunamadı")

        self._source_id = GLib.io_add_watch(self.display.fileno(), GLib.IO_IN, self._on_x_events)
        return self._install_grab()

    # MARK: - Grab installation and retries / Grab kurulumu ve tekrar denemeler

    def _install_grab(self, attempt=0):
        """Try the passive grab once; plan another attempt when Alt+Tab is taken.

        Pasif grab'i bir kez dene; Alt+Tab alınmışsa yeni bir deneme planla."""
        if self.display is None:
            return False
        if self._grabbing:
            return self._grabbed
        self._grabbing = True
        blocked = False
        try:
            tab_keycode = self.keycodes.get("tab")
            for extra in GRAB_EXTRA_MODIFIERS:
                del self._x_errors[:]
                self.root.grab_key(
                    tab_keycode,
                    X.Mod1Mask | extra,
                    True,
                    X.GrabModeAsync,
                    X.GrabModeAsync,
                )
                self.display.sync()
                if any(isinstance(error, BadAccess) for error in self._x_errors):
                    # Only plain Mod1+Tab is essential; the NumLock variants are best effort, so one
                    # of them failing must not throw away the grab that does work.
                    # Yalnızca düz Mod1+Tab şart; NumLock varyasyonları mümkünse çalışır, birinin
                    # başarısız olması çalışan grab'i çöpe atmamalıdır.
                    if extra == 0:
                        blocked = True
        finally:
            self._grabbing = False

        if blocked:
            self._ungrab_passive()
            self._schedule_retry(attempt)
            return False

        self._grabbed = True
        if attempt:
            self.log("Alt+Tab grab acquired after %d failed attempt(s)" % attempt)

        if self.alt_modifier_mask() is None:
            # Without this check the app looks healthy while no key can ever trigger it: the grab
            # succeeds because nobody else owns Mod1+Tab, but an Alt key outside Mod1 never matches.
            # Bu kontrol olmadan uygulama sağlıklı görünür ama hiçbir tuş onu tetikleyemez: başkası
            # Mod1+Tab'i tutmadığı için grab başarılıdır, ancak Mod1 dışındaki Alt tuşu asla eşleşmez.
            message = self.l.alt_not_mod1(self.describe_modifier_map())
            if message:
                print(message, file=sys.stderr, flush=True)
        return True

    def _schedule_retry(self, attempt):
        """Come back later for the grab instead of exiting.

        Çıkmak yerine grab için sonra tekrar gel."""
        if self._retry_id is not None:
            return
        delays = self.RETRY_DELAYS
        delay = delays[attempt] if attempt < len(delays) else delays[-1]
        self.log("Alt+Tab is owned by another program (attempt %d), retrying in %.2fs"
                 % (attempt + 1, delay))
        self._retry_id = GLib.timeout_add(int(delay * 1000), self._retry_grab, attempt + 1)

    def _retry_grab(self, attempt):
        """GLib timeout callback: one more try / GLib zaman aşımı geri çağrısı: bir deneme daha."""
        self._retry_id = None
        if self.display is not None:
            self._install_grab(attempt)
        return False

    def _ungrab_passive(self):
        """Drop the passive grab we hold / Bizde olan pasif grab'i bırak."""
        tab_keycode = self.keycodes.get("tab")
        if tab_keycode is None or self.root is None:
            return
        for extra in GRAB_EXTRA_MODIFIERS:
            try:
                self.root.ungrab_key(tab_keycode, X.Mod1Mask | extra)
            except Exception:
                pass
        try:
            self.display.sync()
        except Exception:
            pass

    def _reinstall_grab(self):
        """The keyboard map changed, so install the grab again.

        Klavye haritası değişti, grab'i yeniden kur."""
        if self.display is None or self._grabbing or self.active or self._regrabbing:
            return
        self._regrabbing = True
        try:
            self._ungrab_passive()
            self._install_grab()
        finally:
            self._regrabbing = False

    def alt_modifier_mask(self):
        """Mask bit name for the Alt key, or None when Alt is outside Mod1.

        Alt tuşunun maskesi; Alt Mod1 dışındaysa None."""
        if self.display is None or self.alt_keycode is None:
            return None
        try:
            mapping = self.display.get_modifier_mapping()
        except Exception:
            return None
        return modifier_name_for_keycode(mapping, self.alt_keycode)

    def describe_modifier_map(self):
        """Human readable modifier table, for the warning message.

        Uyarı mesajı için okunabilir modifier tablosu."""
        try:
            mapping = self.display.get_modifier_mapping()
        except Exception:
            return "unavailable"
        names = [name.lower() for name in MODIFIER_NAMES]
        parts = []
        for index, keycodes in enumerate(mapping):
            if index < len(names):
                parts.append("%s=%s" % (names[index], [int(k) for k in keycodes if k]))
        return "; ".join(parts)

    def stop(self):
        """Remove the grab, release the keyboard and close the display.
        Grab'i kaldır, klavyeyi bırak ve ekranı kapat."""
        if self._retry_id is not None:
            GLib.source_remove(self._retry_id)
            self._retry_id = None
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
        try:
            # python-xlib 0.33 exposes GrabKeyboard on the window, not on the display. Calling
            # display.grab_keyboard() raised AttributeError inside the first real Alt+Tab press and
            # the panel never appeared, while stub-based unit tests all passed.
            # python-xlib 0.33 GrabKeyboard'i display uzerinde degil pencere uzerinde sunar.
            # display.grab_keyboard() ilk gercek Alt+Tab basisinda AttributeError verdi ve panel hic
            # acilmadi; sahte nesnelerle yapilan birim testleri ise gecti.
            self.root.grab_keyboard(False, X.GrabModeAsync, X.GrabModeAsync, X.CurrentTime)
            self.display.sync()
            self.keyboard_grabbed = True
        except Exception as exc:
            # The active grab is an optimisation: the Alt watchdog still ends the panel.
            # Aktif grab bir iyilestirmedir: Alt bekcisi paneli yine de kapatir.
            self.log("keyboard grab unavailable:", exc)
            self.keyboard_grabbed = False

    def _ungrab_keyboard(self):
        if not self.keyboard_grabbed or self.display is None:
            return
        try:
            self.display.ungrab_keyboard(X.CurrentTime)
            self.display.sync()
        except Exception as exc:
            self.log("keyboard ungrab failed:", exc)
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
        elif event.type == X.MappingNotify:
            # The keyboard map changed: xmodmap edits, or the window manager reloading its keys at
            # login. A passive grab sticks to modifier mask bits, so it has to be installed again.
            # Klavye haritası değişti: xmodmap düzenlemesi ya da girişte pencere yöneticisinin
            # tuşlarını yeniden yüklemesi. Pasif grab modifier maskesine bağlıdır, yeniden kurulur.
            if getattr(event, "request", X.MappingKeyboard) == X.MappingKeyboard:
                self._reinstall_grab()

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
