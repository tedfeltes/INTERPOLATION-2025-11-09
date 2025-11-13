from __future__ import annotations

import platform
from typing import Optional

from .base import BaseMonitor


class APICallMonitor(BaseMonitor):
    """Placeholder for API call tracing.

    Real API instrumentation on Windows typically requires Event Tracing for Windows
    (ETW) providers or custom DLL injection. This monitor surfaces guidance and can be
    extended by advanced users.
    """

    def __init__(self, emit, poll_interval: float = 10.0) -> None:
        super().__init__("APICallMonitor", emit, poll_interval=poll_interval)
        self._notified = False
        self._etw_monitor: Optional["ETWSession"] = None

    def set_logging_active(self, active: bool) -> None:
        super().set_logging_active(active)
        if self._etw_monitor:
            if active:
                self._etw_monitor.start_tracing()
            else:
                self._etw_monitor.stop_tracing()

    def stop(self) -> None:
        super().stop()
        if self._etw_monitor:
            self._etw_monitor.dispose()

    def poll(self, pid: int) -> None:
        if platform.system() != "Windows":
            self._notify_once(
                "[API] API tracing is only supported on Windows via Event Tracing for Windows (ETW)."
            )
            return

        if self._etw_monitor is None:
            self._initialise_etw(pid)
        else:
            self._etw_monitor.flush_buffer()

    def _initialise_etw(self, pid: int) -> None:
        try:
            from .etw import ETWSession  # type: ignore
        except Exception as exc:  # pragma: no cover - optional dependency
            self._notify_once(
                "[API] Optional dependency for ETW tracing not available. Install 'python-etw' "
                f"or 'krabsetw' bindings. Details: {exc}"
            )
            return

        self._etw_monitor = ETWSession(pid=pid, emit=self._emit)
        try:
            self._etw_monitor.setup()
        except RuntimeError as exc:
            self._notify_once(f"[API] {exc}")
            self._etw_monitor = None
            return

        if self._logging_active.is_set():
            self._etw_monitor.start_tracing()
        self._notify_once("[API] ETW session initialised for Win32 API monitoring.")

    def _notify_once(self, message: str) -> None:
        if not self._notified:
            self._emit(message)
            self._notified = True
