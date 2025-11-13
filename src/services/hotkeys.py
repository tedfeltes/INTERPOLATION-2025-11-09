from __future__ import annotations

from typing import Callable, Optional


class GlobalHotkeys:
    """Register and manage system-wide keyboard shortcuts."""

    def __init__(
        self,
        on_start: Callable[[], None],
        on_stop: Callable[[], None],
        status_callback: Callable[[str], None],
        *,
        start_combo: str = "ctrl+shift+alt+s",
        stop_combo: str = "ctrl+shift+alt+e",
    ) -> None:
        self._on_start = on_start
        self._on_stop = on_stop
        self._status_callback = status_callback
        self._start_combo = start_combo
        self._stop_combo = stop_combo
        self._keyboard_module: Optional[object] = None
        self._start_token = None
        self._stop_token = None

    def register(self) -> bool:
        try:
            import keyboard  # type: ignore
        except ImportError as exc:
            self._status_callback(
                f"Global hotkeys disabled: install the 'keyboard' package ({exc})."
            )
            return False
        except PermissionError as exc:  # pragma: no cover - platform dependent
            self._status_callback(
                f"Global hotkeys unavailable due to permission error: {exc}"
            )
            return False

        self._keyboard_module = keyboard
        try:
            self._start_token = keyboard.add_hotkey(self._start_combo, self._on_start)
            self._stop_token = keyboard.add_hotkey(self._stop_combo, self._on_stop)
            self._status_callback(
                f"Hotkeys registered: start={self._start_combo}, stop={self._stop_combo}"
            )
            return True
        except Exception as exc:  # pragma: no cover - defensive
            self._status_callback(f"Failed to register hotkeys: {exc}")
            return False

    def unregister(self) -> None:
        if not self._keyboard_module:
            return
        try:
            if self._start_token is not None:
                self._keyboard_module.remove_hotkey(self._start_token)
            if self._stop_token is not None:
                self._keyboard_module.remove_hotkey(self._stop_token)
        except Exception:  # pragma: no cover - defensive
            pass
        finally:
            self._start_token = None
            self._stop_token = None
            self._keyboard_module = None
