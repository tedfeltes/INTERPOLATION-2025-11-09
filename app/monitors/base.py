"""
Base classes and shared utilities for monitoring components.
"""

from __future__ import annotations

import threading
from abc import ABC, abstractmethod
from typing import Optional

from app.logger import LogManager


class BaseMonitor(ABC):
    """Provides a reusable threading scaffold for long-running monitor tasks."""

    def __init__(self, name: str, log_manager: LogManager) -> None:
        self.name = name
        self._log_manager = log_manager
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self._lock = threading.Lock()

    @property
    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def start(self) -> None:
        with self._lock:
            if self.is_running:
                return
            self._stop_event.clear()
            worker = threading.Thread(target=self._run_wrapper, name=f"{self.name}Monitor", daemon=True)
            self._thread = worker
            worker.start()

    def stop(self) -> None:
        with self._lock:
            self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=3)
        self._thread = None

    def log_event(self, category: str, message: str, details: Optional[dict] = None) -> None:
        self._log_manager.log_event(category, message, details)

    def should_stop(self) -> bool:
        return self._stop_event.is_set()

    def _run_wrapper(self) -> None:
        try:
            self.on_start()
            self._run()
        finally:
            self.on_stop()

    def on_start(self) -> None:
        """Optional hook invoked before the monitor thread enters the main loop."""

    def on_stop(self) -> None:
        """Optional hook invoked when the monitor thread terminates."""

    @abstractmethod
    def _run(self) -> None:
        """Main loop executed on the monitor thread."""

