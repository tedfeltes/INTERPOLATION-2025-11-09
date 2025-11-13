"""
Monitor responsible for capturing user keyboard and mouse input.

This module leverages the pynput package to hook keyboard and mouse events.
On Windows and most desktop environments, this requires the script to run
with sufficient privileges. If the pynput back-end cannot be initialised,
the monitor logs a warning and remains inactive.
"""

from __future__ import annotations

import logging
from typing import Optional

try:
    from pynput import keyboard, mouse
except Exception:  # pragma: no cover - import errors are captured at runtime
    keyboard = None  # type: ignore
    mouse = None  # type: ignore

import time

from app.monitors.base import BaseMonitor


class UserInputMonitor(BaseMonitor):
    """Hooks into global keyboard and mouse events using pynput listeners."""

    def __init__(self, log_manager) -> None:
        super().__init__("UserInput", log_manager)
        self._keyboard_listener: Optional["keyboard.Listener"] = None
        self._mouse_listener: Optional["mouse.Listener"] = None

    def on_start(self) -> None:
        if keyboard is None or mouse is None:
            self.log_event("USER_INPUT", "pynput is unavailable; user input logging is disabled.")
            return

        try:
            self._keyboard_listener = keyboard.Listener(on_press=self._on_key_press, on_release=self._on_key_release)
            self._mouse_listener = mouse.Listener(on_click=self._on_click, on_scroll=self._on_scroll)
            self._keyboard_listener.start()
            self._mouse_listener.start()
            self.log_event("USER_INPUT", "User input monitoring started.")
        except Exception as exc:  # pragma: no cover - depends on host OS
            logging.getLogger(__name__).exception("Failed to start input listeners: %s", exc)
            self.log_event("USER_INPUT", "Failed to start pynput listeners.", {"error": str(exc)})

    def on_stop(self) -> None:
        if self._keyboard_listener:
            self._keyboard_listener.stop()
            self._keyboard_listener = None
        if self._mouse_listener:
            self._mouse_listener.stop()
            self._mouse_listener = None
        self.log_event("USER_INPUT", "User input monitoring stopped.")

    def _run(self) -> None:
        # Listener threads are managed by pynput. This monitor simply waits until stop is requested.
        while not self.should_stop():
            # Sleep lightly to yield execution.
            time.sleep(0.25)

    # --- Event handlers -------------------------------------------------

    def _on_key_press(self, key) -> None:  # pragma: no cover - hardware dependent
        self.log_event("USER_INPUT", "Key press detected.", {"key": self._normalise_key(key)})

    def _on_key_release(self, key) -> None:  # pragma: no cover - hardware dependent
        self.log_event("USER_INPUT", "Key release detected.", {"key": self._normalise_key(key)})

    def _on_click(self, x, y, button, pressed) -> None:  # pragma: no cover
        action = "pressed" if pressed else "released"
        self.log_event(
            "USER_INPUT",
            f"Mouse button {action}.",
            {"button": str(button), "position": {"x": x, "y": y}},
        )

    def _on_scroll(self, x, y, dx, dy) -> None:  # pragma: no cover
        self.log_event(
            "USER_INPUT",
            "Mouse scroll event.",
            {"position": {"x": x, "y": y}, "offset": {"dx": dx, "dy": dy}},
        )

    @staticmethod
    def _normalise_key(key) -> str:  # pragma: no cover - depends on pynput internals
        try:
            return key.char  # type: ignore[attr-defined]
        except AttributeError:
            return str(key)
