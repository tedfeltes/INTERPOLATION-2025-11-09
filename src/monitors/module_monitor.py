from __future__ import annotations

import psutil

from .base import BaseMonitor


class ModuleLoadMonitor(BaseMonitor):
    """Detect libraries/DLLs loaded by the process."""

    def __init__(self, emit, poll_interval: float = 2.0) -> None:
        super().__init__("ModuleLoadMonitor", emit, poll_interval=poll_interval)
        self._seen_modules: set[str] = set()

    def poll(self, pid: int) -> None:
        try:
            process = psutil.Process(pid)
        except psutil.NoSuchProcess:
            self.stop()
            return

        processes = [process] + process.children(recursive=True)
        for proc in processes:
            try:
                for mapping in proc.memory_maps():
                    path = mapping.path
                    if path and path not in self._seen_modules:
                        self._seen_modules.add(path)
                        self._emit(
                            f"[Module] pid={proc.pid} loaded {path} "
                            f"(rss={mapping.rss} bytes, private={mapping.private} bytes)"
                        )
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
