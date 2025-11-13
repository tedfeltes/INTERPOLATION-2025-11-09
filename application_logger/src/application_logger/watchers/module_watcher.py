"""Observes dynamically loaded libraries and memory maps."""
from __future__ import annotations

import os
import time
from typing import Set

import psutil

from .base import BaseWatcher


class ModuleWatcher(BaseWatcher):
    """Reports when new modules/libraries are loaded by the target process."""

    def __init__(self, pid: int, log_callback, poll_interval: float = 3.0) -> None:
        super().__init__("modules", log_callback)
        self._pid = pid
        self._poll_interval = poll_interval
        self._loaded_modules: Set[str] = set()

    def run(self) -> None:
        try:
            proc = psutil.Process(self._pid)
        except psutil.NoSuchProcess:
            self.log("lifecycle", "Target process exited before module monitoring started", {"pid": self._pid})
            return
        except psutil.Error as exc:
            self.log("error", "Unable to attach to process for module monitoring", {"pid": self._pid, "exception": repr(exc)})
            return

        self.log("status", "Module watcher attached", {"pid": proc.pid})

        while not self.should_stop():
            try:
                maps = proc.memory_maps()
            except psutil.NoSuchProcess:
                self.log("lifecycle", "Target process ended during module polling", {"pid": proc.pid})
                break
            except psutil.AccessDenied as exc:
                self.log("error", "Insufficient privileges to inspect loaded modules", {"exception": repr(exc)})
                break
            except psutil.Error as exc:
                self.log("error", "Module polling failed", {"exception": repr(exc)})
                break

            current = {m.path for m in maps if m.path}
            current = {normalize_path(path) for path in current if path}

            for path in current - self._loaded_modules:
                self.log(
                    "module_loaded",
                    f"Module loaded: {path}",
                    {"path": path},
                )

            for path in self._loaded_modules - current:
                self.log(
                    "module_unloaded",
                    f"Module unloaded: {path}",
                    {"path": path},
                )

            self._loaded_modules = current
            time.sleep(self._poll_interval)

        self.log("status", "Module watcher stopped", {"pid": proc.pid})


def normalize_path(path: str) -> str:
    try:
        return os.path.normpath(path)
    except Exception:
        return path

