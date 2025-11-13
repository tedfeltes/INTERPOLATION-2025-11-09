from __future__ import annotations

import threading
import time
from typing import Callable, Optional


class BaseMonitor(threading.Thread):
    """Base class for polling-style monitors.

    Subclasses should implement :meth:`poll` and push structured log entries through
    the supplied `emit` callable when logging is enabled.
    """

    def __init__(
        self,
        name: str,
        emit: Callable[[str], None],
        poll_interval: float = 1.0,
        *,
        daemon: bool = True,
    ) -> None:
        super().__init__(name=name, daemon=daemon)
        self._emit = emit
        self._poll_interval = poll_interval
        self._logging_active = threading.Event()
        self._stop_event = threading.Event()
        self._target_pid: Optional[int] = None

    def configure(self, target_pid: Optional[int]) -> None:
        """Inject the PID the monitor should observe."""
        self._target_pid = target_pid

    def set_logging_active(self, active: bool) -> None:
        if active:
            self._logging_active.set()
        else:
            self._logging_active.clear()

    def stop(self) -> None:
        self._stop_event.set()

    def run(self) -> None:
        while not self._stop_event.is_set():
            if not self._logging_active.is_set():
                time.sleep(min(self._poll_interval, 0.25))
                continue

            try:
                if self._target_pid is None:
                    time.sleep(min(self._poll_interval, 0.25))
                    continue
                self.poll(self._target_pid)
            except Exception as exc:  # pragma: no cover - defensive
                self._emit(f"[{self.name}] Error: {exc}")
            finally:
                time.sleep(self._poll_interval)

        self.on_stop()

    def poll(self, pid: int) -> None:  # pragma: no cover - abstract
        raise NotImplementedError

    def on_stop(self) -> None:
        """Optional hook for releasing resources."""
        pass
