"""Event-routing tests for the hotkey handler, with fake X events and no display.

Tuş yönlendirme testleri: sahte X olaylarıyla, ekran gerekmeden.

Synthetic key injection cannot exercise passive grabs (XTest events do not trigger them on this
server), so these tests drive the handler directly: they are what actually proves that a press
starts the panel, Tab cycles, Return commits, Esc cancels and releasing Alt commits.
Sentetik tuş enjeksiyonu pasif grab'i tetikleyemediği için (bu sunucuda XTest olayları grab'i
tetiklemez) testler işleyiciyi doğrudan sürer: panelin açılmasını, Tab'ın gezmesini, Return'ün
onaylamasını, Esc'in iptalini ve Alt bırakılmasının onaylamasını kanıtlayan şey budur.
"""

import importlib.util
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

HAVE_DEPS = importlib.util.find_spec("gi") is not None and importlib.util.find_spec("Xlib") is not None

if HAVE_DEPS:
    from Xlib import X

    from x11_hotkey import X11HotKey

TAB = 23
ALT = 64
ESCAPE = 9
RETURN = 36
LEFT = 113
RIGHT = 114
SHIFT = 1 << 0


class FakeEvent:
    """Minimal stand-in for an X KeyPress/KeyRelease event / X olayının asgari taklidi."""

    def __init__(self, keycode, state=0, time=1000):
        self.detail = keycode
        self.state = state
        self.time = time


@unittest.skipUnless(HAVE_DEPS, "PyGObject or python-xlib is missing here")
class TestHotKeyRouting(unittest.TestCase):
    def setUp(self):
        self.calls = []
        self.hotkey = X11HotKey(
            on_start=lambda: self.calls.append("start"),
            on_cycle=lambda delta: self.calls.append(("cycle", delta)),
            on_commit=lambda: self.calls.append("commit"),
            on_cancel=lambda: self.calls.append("cancel"),
            log=lambda *a: None,
        )
        # No display and no real grabs in this test / Bu testte ekran ve gerçek grab yok
        self.hotkey.keycodes = {"tab": TAB, "alt": ALT, "escape": ESCAPE, "return": RETURN, "left": LEFT, "right": RIGHT}
        self.hotkey.alt_keycode = ALT
        self.hotkey._grab_keyboard = lambda: None
        self.hotkey._ungrab_keyboard = lambda: None
        self.hotkey._start_poll = lambda: None
        self.hotkey._stop_poll = lambda: None

    # MARK: - Activating the panel / Panelin açılması

    def test_tab_starts_the_switcher(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask))
        self.assertEqual(self.calls, ["start"])
        self.assertTrue(self.hotkey.active)

    def test_other_keys_do_not_start_it(self):
        self.hotkey._handle_press(FakeEvent(RETURN, state=X.Mod1Mask))
        self.assertEqual(self.calls, [])
        self.assertFalse(self.hotkey.active)

    def test_tab_press_while_open_cycles(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask))
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask, time=1100))
        self.assertEqual(self.calls, ["start", ("cycle", 1)])

    def test_shift_tab_cycles_backwards(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask))
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask | SHIFT, time=1100))
        self.assertEqual(self.calls, ["start", ("cycle", -1)])

    def test_arrows_cycle(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask))
        self.hotkey._handle_press(FakeEvent(LEFT, state=X.Mod1Mask, time=1100))
        self.hotkey._handle_press(FakeEvent(RIGHT, state=X.Mod1Mask, time=1200))
        self.assertEqual(self.calls, ["start", ("cycle", -1), ("cycle", 1)])

    # MARK: - Finishing / Bitirme

    def test_releasing_alt_commits(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask))
        self.hotkey._handle_release(FakeEvent(ALT, state=0, time=1200))
        self.assertEqual(self.calls, ["start", "commit"])
        self.assertFalse(self.hotkey.active)

    def test_return_commits(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask))
        self.hotkey._handle_press(FakeEvent(RETURN, state=X.Mod1Mask, time=1100))
        self.assertEqual(self.calls, ["start", "commit"])

    def test_escape_cancels(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask))
        self.hotkey._handle_press(FakeEvent(ESCAPE, state=X.Mod1Mask, time=1100))
        self.assertEqual(self.calls, ["start", "cancel"])

    def test_release_without_activation_is_ignored(self):
        self.hotkey._handle_release(FakeEvent(ALT, state=0))
        self.assertEqual(self.calls, [])

    def test_commit_twice_only_fires_once(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask))
        self.hotkey._handle_press(FakeEvent(RETURN, state=X.Mod1Mask, time=1100))
        self.hotkey._handle_press(FakeEvent(RETURN, state=X.Mod1Mask, time=1200))
        self.assertEqual(self.calls, ["start", "commit"])

    # MARK: - Auto-repeat / Tuş tekrarı

    def test_auto_repeat_does_not_cycle_twice(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask, time=1000))
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask, time=1000))  # repeat / tekrar
        self.assertEqual(self.calls, ["start"])

    def test_repeat_after_the_window_cycles(self):
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask, time=1000))
        self.hotkey._handle_press(FakeEvent(TAB, state=X.Mod1Mask, time=1200))
        self.assertEqual(self.calls, ["start", ("cycle", 1)])


if __name__ == "__main__":
    unittest.main(verbosity=2)
