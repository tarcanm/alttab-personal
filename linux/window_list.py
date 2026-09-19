"""Window list through libwnck, ordering through the EWMH stacking property.
Pencere listesi libwnck ile, sıralama EWMH stacking özelliği ile.

_NET_CLIENT_LIST_STACKING is defined by EWMH as bottom-to-top, so we read it with python-xlib,
reverse it, and get a deterministic top-to-bottom order. libwnck is used for titles, icons,
minimized state and activation because it already speaks EWMH correctly.
EWMH, _NET_CLIENT_LIST_STACKING'i aşağıdan yukarıya olarak tanımlar; python-xlib ile okuyup ters
çeviririz ve kesin bir yukarıdan aşağıya sıra elde ederiz. Unvan, simge, küçültülmüş durumu ve
aktivasyon için libwnck kullanılır, çünkü EWMH'yi zaten doğru konuşuyor.
"""

from dataclasses import dataclass

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("Wnck", "3.0")

from gi.repository import Gdk, GdkPixbuf, Wnck  # noqa: E402
from Xlib import X as XlibX  # noqa: E402
from Xlib import display as xdisplay  # noqa: E402

from l import L_  # noqa: E402
from logic import app_name_is_useless, clamp_label, humanize_app_name  # noqa: E402

STACKING_ATOM = "_NET_CLIENT_LIST_STACKING"
ICON_SIZE = 20
# Window types we list / Listelediğimiz pencere tipleri
LISTED_TYPES = (Wnck.WindowType.NORMAL,)


@dataclass
class WindowEntry:
    """One switchable window / Geçilebilir tek pencere."""

    xid: int
    title: str
    app_name: str
    minimized: bool
    icon: object = None
    window: object = None

    @property
    def display_title(self):
        return self.title


class WindowList:
    def __init__(self, l=L_):
        self.l = l
        self.screen = Wnck.Screen.get_default()
        self.screen.force_update()
        # A second X connection just for reading the root-window property.
        # Sadece kök pencere özelliğini okumak için ikinci bir X bağlantısı.
        self._xdpy = xdisplay.Display()

    # MARK: - Ordering / Sıralama

    def stacking_order(self):
        """XIDs top-to-bottom, most recently raised first.
        XID'ler yukarıdan aşağıya, en son öne gelen ilk."""
        try:
            root = self._xdpy.screen().root
            atom = self._xdpy.intern_atom(STACKING_ATOM)
            prop = root.get_full_property(atom, XlibX.AnyPropertyType)
            listed = list(prop.value) if prop else []
        except Exception:
            listed = []
        # EWMH says bottom-to-top / EWMH aşağıdan yukarıya der
        return list(reversed(listed))

    def _own_windows(self):
        windows = {}
        for window in self.screen.get_windows():
            try:
                if window.is_skip_tasklist():
                    continue
                if window.get_window_type() not in LISTED_TYPES:
                    continue
                windows[window.get_xid()] = window
            except Exception:
                continue
        return windows

    def refresh(self):
        """Build the list: active window first, then top-to-bottom stacking order.
        Listeyi kur: önce aktif pencere, sonra yukarıdan aşağıya yığın sırası."""
        active = self.screen.get_active_window()
        active_xid = active.get_xid() if active is not None else None

        known = self._own_windows()
        ordered = []
        seen = set()

        if active_xid in known:
            ordered.append(known[active_xid])
            seen.add(active_xid)

        for xid in self.stacking_order():
            if xid in known and xid not in seen:
                ordered.append(known[xid])
                seen.add(xid)

        # Anything libwnck knows but EWMH did not list, e.g. after a WM restart.
        # EWMH'de görünmeyen ama libwnck'in bildiği pencereler, ör. WM yeniden başladığında.
        for xid, window in known.items():
            if xid not in seen:
                ordered.append(window)
                seen.add(xid)

        entries = [self._entry(window) for window in ordered]
        return [entry for entry in entries if entry is not None]

    def _app_name(self, window, title):
        """Application name, with a WM_CLASS fallback.

        libwnck sometimes reports the window title as the application name (Chrome did on this
        machine), which made the panel print the same text twice. When that happens, fall back to
        WM_CLASS, which is always set.

        Uygulama adı, WM_CLASS yedeğiyle. libwnck bazen uygulama adı olarak pencere başlığını
        verir (bu makinede Chrome öyleydi) ve panel aynı metni iki kez yazar. O durumda her zaman
        tanımlı olan WM_CLASS'a düşeriz.
        """
        name = ""
        try:
            application = window.get_application()
            if application is not None:
                name = clamp_label(application.get_name() or "")
        except Exception:
            name = ""
        if name and not app_name_is_useless(name, title):
            return name
        from_class = self._wm_class(window.get_xid())
        return from_class or name or self.l.application

    def _wm_class(self, xid):
        """Read WM_CLASS for a window, e.g. b"google-chrome\0Google-chrome\0".

        Bir pencerenin WM_CLASS değerini oku.
        """
        try:
            window = self._xdpy.create_resource_object("window", xid)
            prop = window.get_full_property(self._xdpy.intern_atom("WM_CLASS"), XlibX.AnyPropertyType)
            if prop is None:
                return ""
            raw = prop.value
            if isinstance(raw, bytes):
                parts = [part for part in raw.split(b"\x00") if part]
                raw = parts[-1].decode("utf-8", "replace") if parts else ""
            return humanize_app_name(str(raw))
        except Exception:
            return ""

    def _entry(self, window):
        try:
            title = clamp_label(window.get_name() or "")
            app_name = self._app_name(window, title)
            if not title:
                title = f"{app_name} ({self.l.untitled_window})"
            return WindowEntry(
                xid=window.get_xid(),
                title=title,
                app_name=app_name,
                minimized=bool(window.is_minimized()),
                icon=self._scaled_icon(window),
                window=window,
            )
        except Exception:
            return None

    def _scaled_icon(self, window):
        try:
            pixbuf = window.get_icon()
            if pixbuf is None:
                application = window.get_application()
                pixbuf = application.get_icon() if application else None
            if pixbuf is None:
                return None
            return pixbuf.scale_simple(ICON_SIZE, ICON_SIZE, GdkPixbuf.InterpType.BILINEAR)
        except Exception:
            return None

    # MARK: - Activation / Aktivasyon

    def server_time(self):
        """Current X server time, needed when no key event gave us one.

        Anahtar olayı zaman damgası vermediyse gereken güncel X sunucu zamanı.
        """
        try:
            gi.require_version("GdkX11", "3.0")
            from gi.repository import GdkX11

            return int(GdkX11.x11_get_server_time(Gdk.get_default_root_window()))
        except Exception:
            return 0

    def activate(self, entry, timestamp=0):
        """Raise and focus the window. Returns True on success.
        Pencereyi öne al ve odakla. Başarılıysa True döner."""
        window = getattr(entry, "window", None)
        if window is None:
            return False
        if not timestamp:
            # A zero timestamp makes some window managers ignore the request.
            # Sıfır zaman damgasını bazı pencere yöneticileri yok sayar.
            timestamp = self.server_time()
        try:
            if entry.minimized:
                window.unminimize(int(timestamp))
            window.activate(int(timestamp))
            return True
        except Exception:
            return False

    # MARK: - Geometry / Geometri

    def panel_origin(self, width, height):
        """Where to place the panel: centered on the monitor holding the pointer.
        Panelin yeri: imlecin bulunduğu monitörün ortası."""
        try:
            pointer = self._xdpy.screen().root.query_pointer()
            gdk_screen = Gdk.Screen.get_default()
            monitor = gdk_screen.get_monitor_at_point(pointer.root_x, pointer.root_y)
            area = gdk_screen.get_monitor_workarea(monitor)
        except Exception:
            area = None
        if area is None:
            screen = Gdk.Screen.get_default()
            area = Gdk.Rectangle()
            area.x, area.y = 0, 0
            area.width = screen.get_width()
            area.height = screen.get_height()
        x = area.x + max(0, (area.width - width) // 2)
        y = area.y + max(0, (area.height - height) // 2)
        return x, y
