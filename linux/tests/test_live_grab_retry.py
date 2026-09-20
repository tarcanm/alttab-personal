#!/usr/bin/env python3
"""Live test: the passive Alt+Tab grab must retry instead of giving up.

Canlı test: pasif Alt+Tab grab'i vazgeçmek yerine tekrar denemeli.

Needs a real X display. Use the desktop itself, or a throwaway Xvfb server:
    DISPLAY=:0 XAUTHORITY=~/.Xauthority python3 tests/test_live_grab_retry.py
    Xvfb :99 & DISPLAY=:99 python3 tests/test_live_grab_retry.py

Gerçek bir X ekranı gerekir. Ya masaüstünün kendisi, ya da atıl bir Xvfb sunucusu kullanın.
"""

import os
import sys
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from Xlib import X, XK, display  # noqa: E402
from Xlib.error import BadAccess  # noqa: E402

from gi.repository import GLib  # noqa: E402

import x11_hotkey  # noqa: E402

VARIANTS = (0, X.LockMask, X.Mod2Mask, X.LockMask | X.Mod2Mask)


def xdisplay():
    """A working X connection, or None / Çalışan bir X bağlantısı, yoksa None."""
    try:
        conn = display.Display()
    except Exception:
        return None
    return conn


def pump(seconds, callback=None):
    """Run the GLib main loop for a while / GLib ana döngüsünü bir süre çalıştır."""
    context = GLib.MainContext.default()
    end = time.time() + seconds
    while time.time() < end:
        context.iteration(False)
        if callback is not None:
            callback()
        time.sleep(0.02)


class Blocker:
    """Hold Mod1+Tab so the app cannot have it / Alt+Tab'i biz tutalım."""

    def __init__(self, conn):
        self.display = conn
        self.root = conn.screen().root
        self.tab = conn.keysym_to_keycode(XK.string_to_keysym("Tab"))
        self.errors = []
        conn.set_error_handler(lambda error, request: self.errors.append(error))

    def grab(self):
        del self.errors[:]
        for extra in VARIANTS:
            self.root.grab_key(self.tab, X.Mod1Mask | extra, True, X.GrabModeAsync, X.GrabModeAsync)
        self.display.sync()
        return not any(isinstance(error, BadAccess) for error in self.errors)

    def release(self):
        for extra in VARIANTS:
            self.root.ungrab_key(self.tab, X.Mod1Mask | extra)
        self.display.sync()


class GrabRetryTest(unittest.TestCase):
    def setUp(self):
        self.conn = xdisplay()
        if self.conn is None:
            self.skipTest("no X display / X ekranı yok")
        self.blocker = Blocker(self.conn)
        self.messages = []

    def tearDown(self):
        try:
            self.blocker.release()
        except Exception:
            pass
        try:
            self.conn.close()
        except Exception:
            pass

    def hotkey(self):
        return x11_hotkey.X11HotKey(
            lambda: None, lambda delta: None, lambda: None, lambda: None,
            log=self.messages.append,
        )

    def test_blocked_grab_keeps_the_process_alive_and_logs_retries(self):
        # Exactly the login situation: someone else owns Alt+Tab when the app starts. Before this
        # change start() raised HotKeyUnavailable, the app exited and Alt+Tab stayed dead for the
        # whole session.
        # Giriş anındaki durumun aynısı: uygulama başlarken Alt+Tab başkasında. Bu değişiklikten
        # önce start() HotKeyUnavailable yükseltiyor, uygulama çıkıyor ve Alt+Tab oturum boyunca ölü
        # kalıyordu.
        if not self.blocker.grab():
            self.skipTest("Mod1+Tab is already owned by another client / başka bir istemcide")
        hotkey = self.hotkey()
        try:
            installed = hotkey.start()
            self.assertFalse(installed, "start() must report a pending grab instead of raising")
            pump(2.0)
            self.assertTrue(
                any("retrying in" in message for message in self.messages),
                "no retry was logged: %r" % (self.messages,),
            )
        finally:
            hotkey.stop()

    def test_grab_recovers_once_the_combination_is_freed(self):
        # The real fix: after the window manager lets go of Alt+Tab the app takes it without a
        # restart, within the backoff schedule.
        # Asıl düzeltme: pencere yöneticisi Alt+Tab'i bıraktığında uygulama yeniden başlatmadan,
        # artan aralıklı denemelerle kombinasyonu alır.
        if not self.blocker.grab():
            self.skipTest("Mod1+Tab is already owned by another client / başka bir istemcide")
        hotkey = self.hotkey()
        released = []
        try:
            self.assertFalse(hotkey.start())
            pump(1.0)
            self.blocker.release()
            released.append(True)
            pump(6.0)
            self.assertTrue(hotkey._grabbed, "the grab never recovered: %r" % (self.messages,))
            self.assertTrue(
                any("acquired after" in message for message in self.messages),
                "recovery was not logged: %r" % (self.messages,),
            )
        finally:
            hotkey.stop()
            if not released:
                self.blocker.release()


if __name__ == "__main__":
    unittest.main(verbosity=2)
