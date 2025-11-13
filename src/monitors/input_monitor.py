from __future__ import annotations

import threading
from typing import Callable, Optional


class InputMonitor:
    """Capture global keyboard and mouse activity."""

    def __init__(self, emit: Callable[[str], None]) -> None:
        self._emit = emit
        self._logging_active = threading.Event()
        self._keyboard_listener = None
        self._mouse_listener = None
        self._lock = threading.Lock()

    def configure(self, target_pid: Optional[int]) -> None:
        """Accept PID for API symmetry; not used for global listeners."""
        # No-op: user input is system-wide.

    def start(self) -> None:
        if self._keyboard_listener or self._mouse_listener:
            return
        try:
            from pynput import keyboard, mouse
        except ImportError as exc:  # pragma: no cover - runtime dependency
            self._emit(f"[InputMonitor] Unable to import pynput: {exc}")
            return

        self._keyboard_listener = keyboard.Listener(
            on_press=self._on_key_press, on_release=self._on_key_release
        )
        self._mouse_listener = mouse.Listener(
            on_click=self._on_click, on_scroll=self._on_scroll, on_move=self._on_move
        )
        self._keyboard_listener.start()
        self._mouse_listener.start()
        self._emit("[InputMonitor] Global input listeners initialised.")

    def stop(self) -> None:
        with self._lock:
            for listener in (self._keyboard_listener, self._mouse_listener):
                if listener:
                    listener.stop()
            self._keyboard_listener = None
            self._mouse_listener = None
        self._emit("[InputMonitor] Global input listeners stopped.")

    def set_logging_active(self, active: bool) -> None:
        if active:
            self._logging_active.set()
        else:
            self._logging_active.clear()

    def _guard_emit(self, message: str) -> None:
        if self._logging_active.is_set():
            self._emit(message)

    def _on_key_press(self, key) -> None:  # pragma: no cover - requires OS hooks
        try:
            key_name = key.char if hasattr(key, "char") else str(key)
        except Exception:
            key_name = repr(key)
        self._guard_emit(f"[Input] Key pressed: {key_name}")

    def _on_key_release(self, key) -> None:  # pragma: no cover - requires OS hooks
        try:
            key_name = key.char if hasattr(key, "char") else str(key)
        except Exception:
            key_name = repr(key)
        self._guard_emit(f"[Input] Key released: {key_name}")

    def _on_click(self, x, y, button, pressed) -> None:  # pragma: no cover
        state = "down" if pressed else "up"
        self._guard_emit(f"[Input] Mouse {button} {state} at ({x}, {y})")

    def _on_scroll(self, x, y, dx, dy) -> None:  # pragma: no cover
        self._guard_emit(f"[Input] Mouse scroll ({dx}, {dy}) at ({x}, {y})")

    def _on_move(self, x, y) -> None:  # pragma: no cover
        self._guard_emit(f"[Input] Mouse move to ({x}, {y})")
