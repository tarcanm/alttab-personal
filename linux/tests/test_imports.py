"""Smoke test: every module must import, so a broken import fails here and not at startup.
Duman testi: her modül import edilebilmeli; bozuk bir import başlangıçta değil burada yakalanır.

It needs PyGObject for the GTK modules and skips those when it is missing.
GTK modülleri için PyGObject gerekir, yoksa o testler atlanır.
"""

import importlib
import importlib.util
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

CORE_MODULES = ("logic", "l")
GI_MODULES = ("x11_hotkey", "window_list", "panel", "alttab_personal")
HAVE_GI = importlib.util.find_spec("gi") is not None


class TestImports(unittest.TestCase):
    def test_core_modules(self):
        for name in CORE_MODULES:
            with self.subTest(module=name):
                self.assertIsNotNone(importlib.import_module(name))

    @unittest.skipUnless(HAVE_GI, "PyGObject is not installed here")
    def test_display_reachability_check(self):
        """A bogus display must be reported as unreachable, not crash the app.

        Sahte bir ekran erişilemez olarak bildirilmeli, uygulamayı çökertmemeli."""
        import alttab_personal

        self.assertFalse(alttab_personal.display_reachable(":99"))
        self.assertIn("display_missing", dir(alttab_personal.L_))

    @unittest.skipUnless(HAVE_GI, "PyGObject is not installed here")
    def test_gi_modules(self):
        for name in GI_MODULES:
            with self.subTest(module=name):
                self.assertIsNotNone(importlib.import_module(name))


if __name__ == "__main__":
    unittest.main(verbosity=2)
