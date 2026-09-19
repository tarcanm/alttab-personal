"""Tests that talk to a real X display; skipped when there is none.

These exist because stub-based unit tests hid a wrong python-xlib method name that only blew up on
the first real keypress. Run them on the desktop machine (stop the running app first).

Gercek X ekraniyla konusan testler; ekran yoksa atlanir. Sahte nesnelerle yapilan birim testleri,
yalnizca ilk gercek tus basisinda patlayan yanlis bir python-xlib metod adini gizlemisti. Bu testleri
masaustu makinesinde kosun (once calisan uygulamayi durdurun).
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from Xlib import X, XK  # noqa: E402
    from Xlib import display as xdisplay  # noqa: E402

    HAVE_XLIB = True
except ImportError:  # pragma: no cover - depends on the machine
    HAVE_XLIB = False


def display_reachable():
    """True when DISPLAY is set and a connection can be opened.
    DISPLAY tanimliysa ve baglanti acilabiliyorsa True."""
    if not HAVE_XLIB or not os.environ.get("DISPLAY"):
        return False
    try:
        connection = xdisplay.Display()
        connection.close()
        return True
    except Exception:
        return False


@unittest.skipUnless(display_reachable(), "no reachable X display / erisilebilir X ekrani yok")
class TestLiveHotKey(unittest.TestCase):
    def setUp(self):
        from x11_hotkey import X11HotKey

        self.hotkey = X11HotKey(
            on_start=lambda: None,
            on_cycle=lambda delta: None,
            on_commit=lambda: None,
            on_cancel=lambda: None,
        )
        self.hotkey.display = xdisplay.Display()
        self.hotkey.root = self.hotkey.display.screen().root
        for name, keysym in (("tab", "Tab"), ("alt", "Alt_L")):
            self.hotkey.keycodes[name] = self.hotkey.display.keysym_to_keycode(
                XK.string_to_keysym(keysym))
        self.hotkey.alt_keycode = self.hotkey.keycodes["alt"]

    def tearDown(self):
        if self.hotkey.keyboard_grabbed:
            self.hotkey._ungrab_keyboard()
        if self.hotkey.display is not None:
            self.hotkey.display.close()

    def test_keyboard_grab_round_trip(self):
        """The exact call that crashed on the first real Alt+Tab press.

        Ilk gercek Alt+Tab basisinda coken cagri."""
        self.assertFalse(self.hotkey.keyboard_grabbed)
        self.hotkey._grab_keyboard()
        self.assertTrue(self.hotkey.keyboard_grabbed)
        self.hotkey._ungrab_keyboard()
        self.assertFalse(self.hotkey.keyboard_grabbed)

    def test_alt_is_bound_to_mod1(self):
        """On this desktop Alt must be Mod1, otherwise Alt+Tab can never fire.
        Bu masaustunde Alt Mod1 olmalidir, aksi halde Alt+Tab asla tetiklenemez."""
        self.assertEqual(self.hotkey.alt_modifier_mask(), "Mod1")
        self.assertIn("mod1", self.hotkey.describe_modifier_map())


if __name__ == "__main__":
    unittest.main(verbosity=2)
