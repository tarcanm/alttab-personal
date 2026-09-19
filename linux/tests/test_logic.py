"""Offline tests: no X11, no GTK. Run with python3 tests/test_logic.py
Çevrimdışı testler: X11 ve GTK yok. python3 tests/test_logic.py ile çalıştır.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from l import L, _detect_turkish  # noqa: E402
from logic import (  # noqa: E402
    app_name_is_useless,
    clamp_label,
    cycle_index,
    humanize_app_name,
    initial_index,
    is_auto_repeat,
    modifier_name_for_keycode,
    visible_range,
)


class TestCycle(unittest.TestCase):
    def test_forward_wraps(self):
        self.assertEqual(cycle_index(0, 1, 3), 1)
        self.assertEqual(cycle_index(2, 1, 3), 0)

    def test_backward_wraps(self):
        self.assertEqual(cycle_index(0, -1, 3), 2)

    def test_empty_list_is_safe(self):
        self.assertEqual(cycle_index(5, 1, 0), 0)
        self.assertEqual(cycle_index(-2, -1, 0), 0)

    def test_initial_index_is_the_previous_window(self):
        self.assertEqual(initial_index(0), 0)
        self.assertEqual(initial_index(1), 0)
        self.assertEqual(initial_index(4), 1)


class TestVisibleRange(unittest.TestCase):
    def test_short_list_shows_everything(self):
        self.assertEqual(visible_range(0, 5, 12), (0, 5))

    def test_selection_is_centered(self):
        self.assertEqual(visible_range(20, 30, 12), (14, 26))

    def test_edges_do_not_scroll_past_the_list(self):
        self.assertEqual(visible_range(0, 30, 12), (0, 12))
        self.assertEqual(visible_range(29, 30, 12), (18, 30))

    def test_empty(self):
        self.assertEqual(visible_range(0, 0, 12), (0, 0))


class TestLabels(unittest.TestCase):
    def test_whitespace_is_collapsed(self):
        self.assertEqual(clamp_label("  a\n b  "), "a b")

    def test_long_titles_are_shortened(self):
        self.assertEqual(clamp_label("x" * 5, 4), "xxx\u2026")
        self.assertEqual(len(clamp_label("y" * 200)), 80)

    def test_none_is_empty(self):
        self.assertEqual(clamp_label(None), "")


class TestAppName(unittest.TestCase):
    def test_wm_class_is_humanized(self):
        self.assertEqual(humanize_app_name("google-chrome"), "Google Chrome")
        self.assertEqual(humanize_app_name("rustdesk"), "Rustdesk")
        self.assertEqual(humanize_app_name("org.gnome.Nautilus"), "Nautilus")
        self.assertEqual(humanize_app_name("RustDesk"), "RustDesk")

    def test_missing_class_falls_back(self):
        self.assertEqual(humanize_app_name("", "Application"), "Application")
        self.assertEqual(humanize_app_name("   "), "")

    def test_title_echo_is_detected(self):
        self.assertTrue(app_name_is_useless("user@host: ~", "user@host: ~"))
        self.assertTrue(app_name_is_useless("", "Thunar"))
        self.assertTrue(app_name_is_useless("x" * 45, "short title"))
        self.assertFalse(app_name_is_useless("Thunar", "user - Thunar"))


class TestBidiControls(unittest.TestCase):
    def test_invisible_controls_are_stripped(self):
        self.assertEqual(clamp_label("a\u202ab\u202cc"), "abc")
        self.assertEqual(clamp_label("\u202a hello \u2069"), "hello")


class TestAutoRepeat(unittest.TestCase):
    def test_same_key_same_time_is_repeat(self):
        self.assertTrue(is_auto_repeat(23, 100, 23, 100))

    def test_same_key_later_is_not_repeat(self):
        self.assertFalse(is_auto_repeat(23, 100, 23, 140))

    def test_different_key_is_not_repeat(self):
        self.assertFalse(is_auto_repeat(23, 100, 64, 100))

    def test_first_event_is_not_repeat(self):
        self.assertFalse(is_auto_repeat(None, None, 23, 100))

    def test_modifier_name_for_keycode(self):
        """The real world failure seen on the MX Linux desktop: Alt_L inside control, mod1 empty.

        MX Linux masaustunde gorulen gercek hata: Alt_L control icinde, mod1 bos."""
        scrambled = [[50, 62], [66], [37, 64, 105, 204], [], [77], [], [133, 134], [92]]
        self.assertEqual(modifier_name_for_keycode(scrambled, 64), "Control")
        healthy = [[50, 62], [66], [37, 105], [64], [77], [], [133, 134], [92]]
        self.assertEqual(modifier_name_for_keycode(healthy, 64), "Mod1")
        self.assertIsNone(modifier_name_for_keycode(scrambled, 99))
        self.assertIsNone(modifier_name_for_keycode([], 64))
        self.assertIsNone(modifier_name_for_keycode(scrambled, None))


class TestLocalization(unittest.TestCase):
    def test_english(self):
        l = L(turkish=False)
        self.assertEqual(l.untitled_window, "Untitled window")
        self.assertEqual(l.minimized, "minimized")

    def test_turkish(self):
        l = L(turkish=True)
        self.assertEqual(l.untitled_window, "Başlıksız pencere")
        self.assertEqual(l.minimized, "küçültülmüş")

    def test_window_count_counts(self):
        self.assertIn("3", L(turkish=False).window_count(3, 2))
        self.assertIn("3", L(turkish=True).window_count(3, 2))

    def test_detection_reads_the_environment(self):
        saved = {var: os.environ.get(var) for var in ("LC_ALL", "LC_MESSAGES", "LANG")}
        try:
            for var in saved:
                os.environ.pop(var, None)
            os.environ["LANG"] = "tr_TR.UTF-8"
            self.assertTrue(_detect_turkish())
            os.environ["LANG"] = "en_US.UTF-8"
            self.assertFalse(_detect_turkish())
        finally:
            for var, value in saved.items():
                if value is None:
                    os.environ.pop(var, None)
                else:
                    os.environ[var] = value


if __name__ == "__main__":
    unittest.main(verbosity=2)
