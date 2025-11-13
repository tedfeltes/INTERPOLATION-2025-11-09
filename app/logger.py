"""
Central logging utilities for the application execution and process logger GUI.

The LogManager exposes a thread-safe interface for recording structured
log events from multiple monitors. Events are queued and written to disk
sequentially to avoid contention across threads.
"""

from __future__ import annotations

import datetime as _dt
import json
import threading
from dataclasses import dataclass
from pathlib import Path
from queue import Empty, Queue
from typing import Any, Dict, Optional

LOG_TIME_FORMAT = "%Y-%m-%d %H:%M:%S.%f"


@dataclass
class LogEntry:
    """Represents a single log entry captured by the application."""

    timestamp: _dt.datetime
    category: str
    message: str
    details: Optional[Dict[str, Any]] = None

    def as_text(self) -> str:
        """Render the entry as a single multiline text block."""
        stamp = self.timestamp.strftime(LOG_TIME_FORMAT)
        header = f"[{stamp}] [{self.category}] {self.message}"
        if not self.details:
            return header

        try:
            detail_blob = json.dumps(self.details, ensure_ascii=False, indent=2, sort_keys=True)
        except (TypeError, ValueError):
            detail_blob = str(self.details)

        return f"{header}\n    Details: {detail_blob}"


class LogManager:
    """Thread-safe manager for persisting log entries to a file."""

    def __init__(self) -> None:
        self._queue: "Queue[LogEntry]" = Queue()
        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._file_lock = threading.Lock()
        self._file_handle: Optional[Any] = None
        self._log_path: Optional[Path] = None

    @property
    def log_path(self) -> Optional[Path]:
        return self._log_path

    def start(self, path: Path) -> None:
        """Initialise the log manager and start the writer thread."""
        resolved = path.expanduser().resolve()
        resolved.parent.mkdir(parents=True, exist_ok=True)

        with self._file_lock:
            if self._thread and self._thread.is_alive():
                # Switch to a new file by closing the existing handle first.
                self._close_file()

            self._log_path = resolved
            self._file_handle = resolved.open("a", encoding="utf-8")
            self._stop_event.clear()

        writer = threading.Thread(target=self._consume_queue, name="LogWriter", daemon=True)
        writer.start()
        self._thread = writer
        self.log_event("SYSTEM", "Log session started", {"file": str(resolved)})

    def log_event(self, category: str, message: str, details: Optional[Dict[str, Any]] = None) -> None:
        """Queue a new log entry."""
        entry = LogEntry(timestamp=_dt.datetime.utcnow(), category=category, message=message, details=details)
        self._queue.put(entry)

    def stop(self) -> None:
        """Flush queued events and stop the writer thread."""
        self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=5)
        with self._file_lock:
            self._close_file()
        self._thread = None
        self._log_path = None

    def _consume_queue(self) -> None:
        """Continuously consume queued log entries until stopped."""
        while True:
            if self._stop_event.is_set() and self._queue.empty():
                break
            try:
                entry = self._queue.get(timeout=0.5)
            except Empty:
                continue
            try:
                self._write_entry(entry)
            finally:
                self._queue.task_done()

        # Flush once more before stopping.
        with self._file_lock:
            if self._file_handle:
                self._file_handle.flush()

    def _write_entry(self, entry: LogEntry) -> None:
        text = entry.as_text()
        with self._file_lock:
            if not self._file_handle:
                return
            self._file_handle.write(text + "\n")
            self._file_handle.flush()

    def _close_file(self) -> None:
        if self._file_handle:
            try:
                self._file_handle.close()
            finally:
                self._file_handle = None


log_manager = LogManager()

