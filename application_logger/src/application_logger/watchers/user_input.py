"""Global keyboard and mouse input logging."""
from __future__ import annotations

import time
from typing import Any

from .base import BaseWatcher


class UserInputWatcher(BaseWatcher):
    """Captures keyboard and mouse activity using pynput."""

    def __init__(self, log_callback) -> None:
        super().__init__("user_input", log_callback)
        self._keyboard_listener: Any = None
        self._mouse_listener: Any = None

    def run(self) -> None:
        try:
            from pynput import keyboard, mouse
        except ImportError as exc:  # pragma: no cover - dependency missing at runtime
            self.log(
                "dependency_error",
                "pynput is required for capturing user input",
                {"exception": repr(exc)},
            )
            return

        self._keyboard_listener = keyboard.Listener(
            on_press=self._on_key_press,
            on_release=self._on_key_release,
            suppress=False,
        )
        self._mouse_listener = mouse.Listener(
            on_click=self._on_mouse_click,
            on_scroll=self._on_mouse_scroll,
        )

        self.log("status", "User input watcher started")
        self._keyboard_listener.start()
        self._mouse_listener.start()

        try:
            while not self.should_stop():
                time.sleep(0.2)
        finally:
            if self._keyboard_listener:
                self._keyboard_listener.stop()
                self._keyboard_listener.join(timeout=1.0)
            if self._mouse_listener:
                self._mouse_listener.stop()
                self._mouse_listener.join(timeout=1.0)
            self.log("status", "User input watcher stopped")

    def _on_key_press(self, key: Any) -> None:
        key_name = self._format_key(key)
        self.log("keyboard_press", f"Key pressed: {key_name}", {"key": key_name})

    def _on_key_release(self, key: Any) -> None:
        key_name = self._format_key(key)
        self.log("keyboard_release", f"Key released: {key_name}", {"key": key_name})

    def _on_mouse_click(self, x: int, y: int, button: Any, pressed: bool) -> None:
        action = "pressed" if pressed else "released"
        self.log(
            "mouse_click",
            f"Mouse {action}: {button} @ ({x}, {y})",
            {"x": x, "y": y, "button": str(button), "pressed": pressed},
        )

    def _on_mouse_scroll(self, x: int, y: int, dx: int, dy: int) -> None:
        self.log(
            "mouse_scroll",
            "Mouse scrolled",
            {"x": x, "y": y, "delta_x": dx, "delta_y": dy},
        )

    @staticmethod
    def _format_key(key: Any) -> str:
        try:
            return key.char if hasattr(key, "char") and key.char else str(key)
        except AttributeError:
            return str(key)

