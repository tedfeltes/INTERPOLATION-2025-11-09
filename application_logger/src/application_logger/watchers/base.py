"""Common watcher abstractions for logging subsystems."""
from __future__ import annotations

import threading
from abc import ABC, abstractmethod
from typing import Any, Callable, Dict, Optional

LogCallback = Callable[[str, str, str, Dict[str, Any]], None]


class BaseWatcher(ABC):
    """Base class for all watchers that emit diagnostic events."""

    def __init__(self, name: str, log_callback: LogCallback) -> None:
        self.name = name
        self._log_callback = log_callback
        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = threading.Thread(
            target=self._run_wrapper,
            name=f"{self.name}-watcher",
            daemon=True,
        )
        self._thread.start()

    def stop(self, timeout: float = 2.0) -> None:
        self._stop_event.set()
        if self._thread:
            self._thread.join(timeout=timeout)

    def is_running(self) -> bool:
        return bool(self._thread and self._thread.is_alive())

    def should_stop(self) -> bool:
        return self._stop_event.is_set()

    def log(self, subtype: str, message: str, metadata: Optional[Dict[str, Any]] = None) -> None:
        try:
            self._log_callback(self.name, subtype, message, metadata or {})
        except Exception:
            # Never let logging failures break watcher threads.
            pass

    def _run_wrapper(self) -> None:
        try:
            self.run()
        except Exception as exc:  # pragma: no cover - best effort logging of watcher failures
            self.log(
                "internal_error",
                f"Watcher '{self.name}' terminated unexpectedly",
                {"exception": repr(exc)},
            )

    @abstractmethod
    def run(self) -> None:
        """Execution entry point for the watcher."""

