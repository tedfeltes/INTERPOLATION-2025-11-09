"""Tracks file interactions for the target process."""
from __future__ import annotations

import time
from typing import Set

import psutil

from .base import BaseWatcher


class FileWatcher(BaseWatcher):
    """Reports when files are opened or closed by the target process."""

    def __init__(self, pid: int, log_callback, poll_interval: float = 2.0) -> None:
        super().__init__("file_activity", log_callback)
        self._pid = pid
        self._poll_interval = poll_interval
        self._open_files: Set[str] = set()

    def run(self) -> None:
        try:
            proc = psutil.Process(self._pid)
        except psutil.NoSuchProcess:
            self.log("lifecycle", "Target process exited before file monitoring started", {"pid": self._pid})
            return
        except psutil.Error as exc:
            self.log("error", "Unable to attach to target for file monitoring", {"pid": self._pid, "exception": repr(exc)})
            return

        self.log("status", "File watcher attached", {"pid": proc.pid})

        while not self.should_stop():
            try:
                files = proc.open_files()
            except psutil.NoSuchProcess:
                self.log("lifecycle", "Target process ended during file polling", {"pid": proc.pid})
                break
            except psutil.AccessDenied as exc:
                self.log("error", "Insufficient privileges to query open files", {"exception": repr(exc)})
                break
            except psutil.Error as exc:
                self.log("error", "File polling failed", {"exception": repr(exc)})
                break

            current = {f.path for f in files}

            for path in current - self._open_files:
                self.log(
                    "file_opened",
                    f"File opened: {path}",
                    {"path": path},
                )

            for path in self._open_files - current:
                self.log(
                    "file_closed",
                    f"File closed: {path}",
                    {"path": path},
                )

            self._open_files = current
            time.sleep(self._poll_interval)

        self.log("status", "File watcher stopped", {"pid": proc.pid})

