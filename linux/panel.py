"""The GTK panel that shows the window list.
Pencere listesini gösteren GTK paneli.

No compositor is required: the panel is an opaque, borderless, non-focusable utility window that
stays above other windows. Transparency and blur are intentionally absent because Fluxbox on this
machine has no running compositor.
Kompozitör gerekmez: panel opak, çerçevesiz, odak almayan ve diğer pencerelerin üstünde kalan bir
utility penceresidir. Şeffaflık ve bulanıklık bilinçli olarak yok, çünkü bu makinedeki Fluxbox'ta
çalışan bir kompozitör yok.
"""

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")

from gi.repository import Gdk, Gtk, Pango  # noqa: E402

from l import L_  # noqa: E402
from logic import visible_range  # noqa: E402

CSS = b"""
.panel { background-color: #2b2b2b; border: 1px solid #555555; }
.row { padding: 5px 10px; }
.row.selected { background-color: #3d6ea5; }
.title { font-size: 11pt; color: #f0f0f0; }
.title.selected { color: #ffffff; }
.app { font-size: 8pt; color: #b0b0b0; }
.app.selected { color: #dce8f5; }
.hint { font-size: 8pt; color: #909090; padding: 4px 10px 6px 10px; }
"""


class Row(Gtk.Box):
    """One row: icon, title, application name / Tek satır: simge, başlık, uygulama adı."""

    def __init__(self, entry, selected, l=L_):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.get_style_context().add_class("row")
        if selected:
            self.get_style_context().add_class("selected")

        image = Gtk.Image()
        if entry.icon is not None:
            image.set_from_pixbuf(entry.icon)
        else:
            image.set_from_icon_name("application-x-executable", Gtk.IconSize.MENU)
        self.pack_start(image, False, False, 0)

        texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        title = Gtk.Label(label=entry.display_title, xalign=0.0)
        title.set_ellipsize(Pango.EllipsizeMode.END)
        title.get_style_context().add_class("title")
        if selected:
            title.get_style_context().add_class("selected")

        subtitle = entry.app_name
        if entry.minimized:
            subtitle = f"{subtitle} ({l.minimized})"
        if subtitle.strip().lower() == entry.display_title.strip().lower():
            # Do not print the same text twice / Aynı metni iki kez yazma
            subtitle = ""
        texts.pack_start(title, False, False, 0)
        if subtitle:
            app = Gtk.Label(label=subtitle, xalign=0.0)
            app.get_style_context().add_class("app")
            if selected:
                app.get_style_context().add_class("selected")
            texts.pack_start(app, False, False, 0)
        self.pack_start(texts, True, True, 0)


class SwitcherPanel:
    def __init__(self, l=L_):
        self.l = l
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_decorated(False)
        self.window.set_resizable(False)
        self.window.set_skip_taskbar_hint(True)
        self.window.set_skip_pager_hint(True)
        self.window.set_keep_above(True)
        self.window.set_accept_focus(False)
        self.window.set_focus_on_map(False)
        self.window.set_type_hint(Gdk.WindowTypeHint.UTILITY)
        self.window.set_position(Gtk.WindowPosition.NONE)
        # Identify our own window: it never appears in the list, but this makes it easy to spot
        # in window listings while debugging.
        # Kendi penceremizi tanımla: listede hiç görünmez ama hata ayıklarken bulmayı kolaylaştırır.
        self.window.set_title("AltTab Personal")
        self.window.set_wmclass("alttab-personal", "AltTabPersonal")
        self.window.connect("delete-event", lambda *_: True)

        self.container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.container.get_style_context().add_class("panel")
        self.window.add(self.container)

        self._install_css()

    def _install_css(self):
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        screen = Gdk.Screen.get_default()
        if screen is not None:
            Gtk.StyleContext.add_provider_for_screen(
                screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    # MARK: - Render / Gösterim

    def render(self, entries, selected):
        for child in self.container.get_children():
            self.container.remove(child)

        start, end = visible_range(selected, len(entries))
        for index in range(start, end):
            self.container.pack_start(Row(entries[index], index == selected, self.l), False, False, 0)

        if len(entries) > (end - start):
            hint = Gtk.Label(label=self.l.window_count(len(entries), end - start), xalign=0.0)
            hint.get_style_context().add_class("hint")
            self.container.pack_start(hint, False, False, 0)

        note = Gtk.Label(label=self.l.navigation_hint, xalign=0.0)
        note.get_style_context().add_class("hint")
        self.container.pack_start(note, False, False, 0)

        self.container.show_all()

    def show_centered(self, x, y):
        """Show the panel at the given origin, without taking focus.
        Paneli verilen konumda, odak almadan göster."""
        natural = self.window.get_preferred_size()[1]
        self.window.resize(max(natural.width, 320), natural.height)
        self.window.move(x, y)
        self.window.show_all()
        self.window.get_window().raise_()

    def hide(self):
        self.window.hide()

    def quit(self):
        Gtk.main_quit()
